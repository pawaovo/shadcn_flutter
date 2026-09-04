// Tests the complete pinned SDK translation unit with real ATK/GObject signals.
// No ATK function, name/state getter, property notification or signal is mocked.
#include <gtest/gtest.h>

#include <string>
#include <vector>

#include "flutter/shell/platform/linux/fl_accessible_node.h"

namespace {

std::string nullable(const gchar* value) {
  return value == nullptr ? "<null>" : value;
}

struct StateEvent {
  std::string name;
  bool value;
  bool expanded_when_notified;
  bool expandable_when_notified;
};

class NativeAtkSourceTest : public ::testing::Test {
 protected:
  void SetUp() override {
    node = fl_accessible_node_new(nullptr, 123, 456);
    ASSERT_NE(node, nullptr);
    g_signal_connect(node, "notify::accessible-name", G_CALLBACK(on_name_notify), this);
    g_signal_connect(node, "property-change::accessible-name", G_CALLBACK(on_property_change), this);
    g_signal_connect(node, "state-change", G_CALLBACK(on_state_change), this);
  }

  void TearDown() override {
    g_clear_object(&node);
  }

  static void on_name_notify(GObject* object, GParamSpec*, gpointer data) {
    auto* self = static_cast<NativeAtkSourceTest*>(data);
    self->notify_names.push_back(nullable(atk_object_get_name(ATK_OBJECT(object))));
  }

  static void on_property_change(AtkObject*, AtkPropertyValues* values, gpointer data) {
    auto* self = static_cast<NativeAtkSourceTest*>(data);
    EXPECT_STREQ(values->property_name, "accessible-name");
    ASSERT_TRUE(G_VALUE_HOLDS_STRING(&values->new_value));
    self->property_names.push_back(nullable(g_value_get_string(&values->new_value)));
  }

  static void on_state_change(AtkObject* object, const gchar* name, gboolean value,
                              gpointer data) {
    auto* self = static_cast<NativeAtkSourceTest*>(data);
    g_autoptr(AtkStateSet) states = atk_object_ref_state_set(object);
    self->state_events.push_back({name, value != FALSE,
        atk_state_set_contains_state(states, ATK_STATE_EXPANDED) != FALSE,
        atk_state_set_contains_state(states, ATK_STATE_EXPANDABLE) != FALSE});
  }

  void set_expanded(FlutterTristate expanded) {
    FlutterSemanticsFlags flags = {};
    flags.struct_size = sizeof(flags);
    flags.is_expanded = expanded;
    fl_accessible_node_set_flags(node, &flags);
  }

  void expect_states(bool expandable, bool expanded) {
    g_autoptr(AtkStateSet) states = atk_object_ref_state_set(ATK_OBJECT(node));
    EXPECT_EQ(atk_state_set_contains_state(states, ATK_STATE_EXPANDABLE) != FALSE, expandable);
    EXPECT_EQ(atk_state_set_contains_state(states, ATK_STATE_EXPANDED) != FALSE, expanded);
  }

  void expect_one_state(const char* name, bool value, bool expandable, bool expanded) {
    ASSERT_EQ(state_events.size(), 1u);
    EXPECT_EQ(state_events[0].name, name);
    EXPECT_EQ(state_events[0].value, value);
    EXPECT_EQ(state_events[0].expanded_when_notified, expanded);
    EXPECT_EQ(state_events[0].expandable_when_notified, expandable);
    state_events.clear();
  }

  FlAccessibleNode* node = nullptr;
  std::vector<std::string> notify_names;
  std::vector<std::string> property_names;
  std::vector<StateEvent> state_events;
};

TEST_F(NativeAtkSourceTest, ChangedNameReachesRealPropertyListenersWithUpdatedValue) {
  fl_accessible_node_set_name(node, "Theme: system");
  notify_names.clear();
  property_names.clear();
  fl_accessible_node_set_name(node, "Theme: light");
  EXPECT_STREQ(atk_object_get_name(ATK_OBJECT(node)), "Theme: light");
  EXPECT_EQ(notify_names, std::vector<std::string>({"Theme: light"}));
  EXPECT_EQ(property_names, std::vector<std::string>({"Theme: light"}));
}

TEST_F(NativeAtkSourceTest, InitialNameIsSilentLikeAtkObjectSetName) {
  fl_accessible_node_set_name(node, "Theme: system");
  EXPECT_STREQ(atk_object_get_name(ATK_OBJECT(node)), "Theme: system");
  EXPECT_TRUE(notify_names.empty());
  EXPECT_TRUE(property_names.empty());
}

TEST_F(NativeAtkSourceTest, EqualNameIsSilent) {
  fl_accessible_node_set_name(node, "Theme: light");
  notify_names.clear();
  property_names.clear();
  fl_accessible_node_set_name(node, "Theme: light");
  EXPECT_STREQ(atk_object_get_name(ATK_OBJECT(node)), "Theme: light");
  EXPECT_TRUE(notify_names.empty());
  EXPECT_TRUE(property_names.empty());
}

TEST_F(NativeAtkSourceTest, EmptyAndUnicodeNamesKeepTheirActualValues) {
  fl_accessible_node_set_name(node, "");
  EXPECT_TRUE(notify_names.empty());
  fl_accessible_node_set_name(node, "主题：浅色");
  fl_accessible_node_set_name(node, "");
  EXPECT_STREQ(atk_object_get_name(ATK_OBJECT(node)), "");
  EXPECT_EQ(notify_names, std::vector<std::string>({"主题：浅色", ""}));
  EXPECT_EQ(property_names, notify_names);
}

TEST_F(NativeAtkSourceTest, PropertyFreezeCoalescesThroughRealGObjectNotification) {
  fl_accessible_node_set_name(node, "");
  g_object_freeze_notify(G_OBJECT(node));
  fl_accessible_node_set_name(node, "Theme: system");
  fl_accessible_node_set_name(node, "Theme: light");
  EXPECT_TRUE(notify_names.empty());
  EXPECT_TRUE(property_names.empty());
  g_object_thaw_notify(G_OBJECT(node));
  EXPECT_EQ(notify_names, std::vector<std::string>({"Theme: light"}));
  EXPECT_EQ(property_names, notify_names);
}

TEST_F(NativeAtkSourceTest, ClearingNameDoesNotSuppressLaterReassignment) {
  fl_accessible_node_set_name(node, "Theme: system");
  fl_accessible_node_set_name(node, nullptr);
  EXPECT_EQ(atk_object_get_name(ATK_OBJECT(node)), nullptr);
  fl_accessible_node_set_name(node, "Theme: light");
  EXPECT_EQ(notify_names, std::vector<std::string>({"<null>", "Theme: light"}));
  EXPECT_EQ(property_names, notify_names);
}

TEST_F(NativeAtkSourceTest, ExplicitInitialNullStillPublishesLaterName) {
  fl_accessible_node_set_name(node, nullptr);
  EXPECT_TRUE(notify_names.empty());
  fl_accessible_node_set_name(node, "Theme: light");
  EXPECT_EQ(notify_names, std::vector<std::string>({"Theme: light"}));
  EXPECT_EQ(property_names, notify_names);
}

TEST_F(NativeAtkSourceTest, TristateExpansionMapsAndNotifiesEveryTransition) {
  set_expanded(kFlutterTristateNone);
  expect_states(false, false);
  EXPECT_TRUE(state_events.empty());

  set_expanded(kFlutterTristateFalse);
  expect_states(true, false);
  expect_one_state("expandable", true, true, false);

  set_expanded(kFlutterTristateTrue);
  expect_states(true, true);
  expect_one_state("expanded", true, true, true);
  set_expanded(kFlutterTristateTrue);
  EXPECT_TRUE(state_events.empty());

  set_expanded(kFlutterTristateFalse);
  expect_states(true, false);
  expect_one_state("expanded", false, true, false);

  set_expanded(kFlutterTristateNone);
  expect_states(false, false);
  expect_one_state("expandable", false, false, false);
}

TEST_F(NativeAtkSourceTest, RemovingExpandedCapabilityPublishesCoherentFinalState) {
  set_expanded(kFlutterTristateTrue);
  state_events.clear();
  set_expanded(kFlutterTristateNone);
  expect_states(false, false);
  ASSERT_EQ(state_events.size(), 2u);
  EXPECT_EQ(state_events[0].name, "expandable");
  EXPECT_EQ(state_events[1].name, "expanded");
  for (const auto& event : state_events) {
    EXPECT_FALSE(event.value);
    EXPECT_FALSE(event.expandable_when_notified);
    EXPECT_FALSE(event.expanded_when_notified);
  }
}

TEST_F(NativeAtkSourceTest, ExpansionPreservesExistingEnabledFocusAndRoleMapping) {
  FlutterSemanticsFlags flags = {};
  flags.struct_size = sizeof(flags);
  flags.is_expanded = kFlutterTristateTrue;
  flags.is_enabled = kFlutterTristateTrue;
  flags.is_focused = kFlutterTristateTrue;
  flags.is_button = true;
  fl_accessible_node_set_flags(node, &flags);
  expect_states(true, true);
  g_autoptr(AtkStateSet) states = atk_object_ref_state_set(ATK_OBJECT(node));
  EXPECT_TRUE(atk_state_set_contains_state(states, ATK_STATE_ENABLED));
  EXPECT_TRUE(atk_state_set_contains_state(states, ATK_STATE_SENSITIVE));
  EXPECT_TRUE(atk_state_set_contains_state(states, ATK_STATE_FOCUSABLE));
  EXPECT_TRUE(atk_state_set_contains_state(states, ATK_STATE_FOCUSED));
  EXPECT_EQ(atk_object_get_role(ATK_OBJECT(node)), ATK_ROLE_PUSH_BUTTON);
}

}  // namespace
