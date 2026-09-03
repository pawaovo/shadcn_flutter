import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import vm from 'node:vm';

const integration = new URL(
  '../../packages/beautiful_ai_ui_catalog/integration_test/',
  import.meta.url,
);
const bridge = readFileSync(
  new URL('support/browser_input_bridge_web.dart', integration),
  'utf8',
);
const bindings = [...bridge.matchAll(/@JS\('([^']+)'\)/g)].map(
  (match) => match[1],
);
assert.equal(
  bindings.length,
  3,
  'Expected state setter and acknowledgement accessors',
);
const [stateBinding, acknowledgementGetter, acknowledgementSetter] = bindings;
assert.equal(acknowledgementGetter, acknowledgementSetter);

for (const file of [
  'catalog_browser_input_driver.dart',
  'catalog_trusted_journey_driver.dart',
]) {
  const source = readFileSync(new URL(`driver/${file}`, integration), 'utf8');
  // Execute the real driver expressions rather than a copy of their protocol.
  const scripts = [...source.matchAll(/r?'([^'\n]*__beautifulInput[^'\n]*)'/g)].map(
    (match) => match[1],
  );
  assert.equal(
    scripts.length,
    2,
    `${file}: expected one state read and one acknowledgement write`,
  );
  const [readStage] = scripts.filter((script) =>
    script.includes('__beautifulInputAcceptance'),
  );
  const [acknowledge] = scripts.filter((script) =>
    script.includes('__beautifulInputAcknowledgement'),
  );

  for (const separateRealm of [false, true]) {
    const realm = separateRealm
      ? 'a fresh WebDriver sandbox'
      : 'a shared window realm';
    test(`${file}: page sees acknowledgements with ${realm}`, () => {
      const page = { $flutterDriverResult: null };
      page.window = page;
      const pageContext = vm.createContext(page);
      const inPage = (script) => vm.runInContext(script, pageContext);
      const execute = (script, args = []) => {
        // Firefox's Marionette creates a fresh sandbox whose prototype is the
        // page window. Reads can inherit page state; writes to globalThis can
        // shadow it. Explicit window access must reach the shared page instead.
        // https://searchfox.org/firefox-main/source/remote/marionette/evaluate.sys.mjs
        const context = separateRealm
          ? vm.createContext(Object.create(page))
          : pageContext;
        context.__webdriverArguments = args;
        return vm.runInContext(
          `(function () { ${script} }).apply(null, __webdriverArguments)`,
          context,
        );
      };

      for (const id of ['journey-code-copy', 'journey-stream-copy']) {
        const state = { stage: id, x: 1278.5, y: 79.5 };
        inPage(`${stateBinding} = ${JSON.stringify(state)}`);
        const value = execute(readStage);
        const actualState = typeof value.stage === 'object' ? value.stage : value;
        assert.equal(JSON.stringify(actualState), JSON.stringify(state));

        assert.equal(execute(acknowledge, [id]), true);
        assert.equal(
          inPage(acknowledgementGetter),
          id,
          'A successful WebDriver script must acknowledge in the application page',
        );

        // Match the bridge reset between actions. A later script must not see
        // state or acknowledgement left behind in a previous execution realm.
        inPage(`${stateBinding} = null; ${acknowledgementSetter} = null`);
        const cleared = execute(readStage);
        assert.equal(cleared === null ? null : cleared.stage, null);
        assert.equal(inPage(acknowledgementGetter), null);
      }
    });
  }
}
