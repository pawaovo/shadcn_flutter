import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import vm from 'node:vm';

const driver = readFileSync(
  new URL(
    '../../packages/beautiful_ai_ui_catalog/integration_test/driver/catalog_browser_input_driver.dart',
    import.meta.url,
  ),
  'utf8',
);
const match = driver.match(
  /const\s+browserAcceptanceSnapshotScript\s*=\s*r'''([\s\S]*?)''';/,
);
assert.ok(match, 'Driver must expose its actual browserAcceptanceSnapshotScript');
const script = match[1];

// These fixtures retain the DOM boundary relevant to the bug: closest() cannot
// cross a shadow root, but getRootNode().host can reach the enclosing Flutter view.
class Element {
  constructor(tagName, parent = null, options = {}) {
    this.nodeType = 1;
    this.tagName = tagName.toUpperCase();
    this.localName = tagName.toLowerCase();
    this.parentNode = parent;
    this.parentElement = parent instanceof Element ? parent : null;
    this.ownerDocument = parent?.ownerDocument ?? parent;
    this.shadowRoot = null;
    this.isConnected = true;
    if (['input', 'textarea'].includes(this.localName)) {
      this.readOnly = false;
      this.disabled = false;
      this.selectionStart = 0;
      this.selectionEnd = 0;
    } else if (this.localName === 'button') {
      this.disabled = false;
    }
    this.className = '';
    Object.assign(this, options);
    this.classList = {
      contains: (name) => this.className.split(/\s+/).includes(name),
    };
  }

  matches(selector) {
    return selector.split(',').some((part) => {
      const value = part.trim();
      return value.startsWith('.')
        ? this.classList.contains(value.slice(1))
        : this.localName === value.toLowerCase();
    });
  }

  closest(selector) {
    for (let node = this; node; node = node.parentElement) {
      if (node.matches(selector)) return node;
    }
    return null;
  }

  getRootNode() {
    let node = this;
    while (node.parentNode) node = node.parentNode;
    return node;
  }

  getAttribute(name) {
    if (name === 'class') return this.className;
    if (name === 'readonly') return this.readOnly ? '' : null;
    if (name === 'disabled') return this.disabled ? '' : null;
    return null;
  }

  hasAttribute(name) {
    return this.getAttribute(name) !== null;
  }

  attachShadow() {
    this.shadowRoot = {
      nodeType: 11,
      host: this,
      parentNode: null,
      ownerDocument: this.ownerDocument,
      activeElement: null,
    };
    return this.shadowRoot;
  }
}

function fixture() {
  const document = {
    nodeType: 9,
    parentNode: null,
    activeElement: null,
    hasFocus: () => true,
  };
  const body = new Element('body', document);
  document.body = body;
  const view = new Element('flutter-view', body);
  return { document, body, view };
}

function snapshot(document) {
  const stage = { stage: 'prompt-type', draft: '', focused: true };
  const result = '{"isError":false,"response":{"message":"test result"}}';
  const acknowledgement = 'previous-action';
  const page = {
    document,
    Element,
    HTMLElement: Element,
    __beautifulInputAcceptance: stage,
    __beautifulInputAcknowledgement: acknowledgement,
    $flutterDriverResult: result,
  };
  page.window = page;
  // Also catch Firefox regressions: a driver's global object can be distinct
  // from the shared page window while inheriting its readable properties.
  const context = vm.createContext(Object.create(page));
  const actual = vm.runInContext(`(function () { ${script} })()`, context);
  assert.equal(JSON.stringify(actual.stage), JSON.stringify(stage));
  assert.equal(actual.result, result);
  assert.equal(actual.acknowledgement, acknowledgement);
  assert.equal(typeof actual.activeEditor, 'object');
  assert.notEqual(actual.activeEditor, null);
  assert.equal(typeof actual.activeEditor.ready, 'boolean');
  return actual.activeEditor;
}

function expectEditor(document, editor, ready) {
  const actual = snapshot(document);
  assert.equal(actual.ready, ready);
  for (const key of [
    'tagName',
    'readOnly',
    'disabled',
    'selectionStart',
    'selectionEnd',
  ]) {
    if (Object.hasOwn(actual, key)) {
      if (key === 'tagName') {
        assert.equal(actual.tagName.toLowerCase(), editor.localName);
        continue;
      }
      const expected = key === 'readOnly' || key === 'disabled'
        ? Boolean(editor[key])
        : editor[key] ?? null;
      assert.equal(actual[key], expected, key);
    }
  }
}

test('focused textarea inside Flutter is ready and preserves selection diagnostics', () => {
  const { document, view } = fixture();
  const editor = new Element('textarea', view, {
    selectionStart: 2,
    selectionEnd: 5,
  });
  document.activeElement = editor;
  expectEditor(document, editor, true);
});

test('finds active input through nested shadow roots and its Flutter ancestor', () => {
  const { document, view } = fixture();
  const host = new Element('flt-glass-pane', view);
  const shadow = host.attachShadow();
  const innerHost = new Element('flt-text-editing-host', shadow);
  const innerShadow = innerHost.attachShadow();
  const editor = new Element('input', innerShadow, {
    selectionStart: 3,
    selectionEnd: 3,
  });
  document.activeElement = host;
  shadow.activeElement = innerHost;
  innerShadow.activeElement = editor;
  assert.equal(editor.closest('flutter-view'), null);
  expectEditor(document, editor, true);
});

test('Flutter text-editing class identifies the engine editor outside flutter-view', () => {
  const { document, body } = fixture();
  const editor = new Element('textarea', body, {
    className: 'flt-text-editing',
  });
  document.activeElement = editor;
  expectEditor(document, editor, true);
});

for (const blocked of ['readOnly', 'disabled']) {
  test(`${blocked} Flutter editor is not ready`, () => {
    const { document, view } = fixture();
    const editor = new Element('textarea', view, { [blocked]: true });
    document.activeElement = editor;
    expectEditor(document, editor, false);
  });
}

test('focused external input is not a Flutter editor', () => {
  const { document, body } = fixture();
  const editor = new Element('input', body);
  document.activeElement = editor;
  expectEditor(document, editor, false);
});

test('focused Flutter button is not ready for text input', () => {
  const { document, view } = fixture();
  const button = new Element('button', view, {
    className: 'flt-text-editing',
  });
  document.activeElement = button;
  expectEditor(document, button, false);
});

test('no active DOM element is not ready', () => {
  const { document } = fixture();
  assert.equal(snapshot(document).ready, false);
});
