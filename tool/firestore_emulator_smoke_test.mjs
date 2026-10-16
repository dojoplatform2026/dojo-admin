// Firestore Emulator REST smoke test.
// This validates emulator document persistence without invoking Firebase's
// native platform channels (which are unavailable in plain `flutter test`).
// It never connects to production Firebase.
const projectId = 'demo-dojo-walk';
const base =
  process.env.FIRESTORE_EMULATOR_REST_URL ??
  `http://127.0.0.1:8080/v1/projects/${projectId}/databases/(default)/documents`;

async function request(path, options = {}) {
  const response = await fetch(`${base}/${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(options.headers ?? {}),
    },
  });
  const text = await response.text();
  if (!response.ok) {
    throw new Error(`Firestore Emulator ${options.method ?? 'GET'} ${path} failed: ${response.status} ${text}`);
  }
  return text ? JSON.parse(text) : null;
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function stringField(value) {
  return { stringValue: value };
}

function fieldsWithLgd(name, lgdCode) {
  return {
    name: stringField(name),
    lgdCode: stringField(lgdCode),
    isActive: { booleanValue: false },
  };
}

function readString(document, field) {
  return document?.fields?.[field]?.stringValue ?? null;
}

const suffix = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
const cases = [
  { collection: 'service_states', id: `ci-state-${suffix}`, name: 'CI State', code: '09' },
  { collection: 'service_cities', id: `ci-district-${suffix}`, name: 'CI District', code: '009' },
  { collection: 'service_areas', id: `ci-subdistrict-${suffix}`, name: 'CI Sub-district', code: '12345' },
];

for (const item of cases) {
  const path = `${item.collection}/${item.id}`;
  const createQuery = new URLSearchParams();
  for (const field of ['name', 'lgdCode', 'isActive']) createQuery.append('updateMask.fieldPaths', field);
  await request(`${path}?${createQuery}`, {
    method: 'PATCH',
    body: JSON.stringify({ fields: fieldsWithLgd(item.name, item.code) }),
  });

  let saved = await request(path);
  assert(readString(saved, 'lgdCode') === item.code,
    `${item.collection}: expected LGD code ${item.code} after save/read`);

  // An explicit update mask for lgdCode with the field omitted removes the
  // old code, matching the nullable-field clearing requirement.
  const clearQuery = new URLSearchParams();
  clearQuery.append('updateMask.fieldPaths', 'lgdCode');
  await request(`${path}?${clearQuery}`, {
    method: 'PATCH',
    body: JSON.stringify({ fields: { name: stringField(item.name), isActive: { booleanValue: false } } }),
  });

  saved = await request(path);
  assert(readString(saved, 'lgdCode') === null,
    `${item.collection}: LGD code was not cleared on update`);
  console.log(`PASS ${item.collection}: save/read/clear LGD code`);
}

console.log('Firestore Emulator REST smoke test passed; production Firebase was not accessed.');
