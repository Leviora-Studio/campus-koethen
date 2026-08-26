import assert from 'node:assert/strict';
import test from 'node:test';
import { roomAdminConfiguration } from '../src/bootstrap/room-admin-configuration';

test('room uses editorLabel as its Content Manager main field', () => {
  const current = {
    settings: { mainField: 'roomKey', defaultSortBy: 'roomKey' },
    layouts: { list: ['roomKey', 'displayNameDe'] },
  };

  const result = roomAdminConfiguration('api::room.room', current);

  assert.equal(result.changed, true);
  assert.deepEqual(result.configuration, {
    settings: { mainField: 'editorLabel', defaultSortBy: 'roomKey' },
    layouts: { list: ['roomKey', 'displayNameDe'] },
  });
});

for (const uid of ['api::contact-area.contact-area', 'api::contact-person.contact-person']) {
  test(`${uid} displays room relations through editorLabel`, () => {
    const current = {
      metadatas: {
        rooms: {
          edit: { label: 'rooms', mainField: 'roomKey' },
          list: { label: 'rooms' },
        },
        name: { edit: { label: 'name' } },
      },
    };

    const result = roomAdminConfiguration(uid, current);

    assert.equal(result.changed, true);
    assert.deepEqual(result.configuration, {
      metadatas: {
        rooms: {
          edit: { label: 'rooms', mainField: 'editorLabel' },
          list: { label: 'rooms' },
        },
        name: { edit: { label: 'name' } },
      },
    });
  });
}

test('an already configured layout produces no write', () => {
  const current = { settings: { mainField: 'editorLabel' } };
  const result = roomAdminConfiguration('api::room.room', current);

  assert.equal(result.changed, false);
  assert.equal(result.configuration, current);
});

test('unrelated content types are left untouched', () => {
  const current = { settings: { mainField: 'title' } };
  const result = roomAdminConfiguration('api::post.post', current);

  assert.equal(result.changed, false);
  assert.equal(result.configuration, current);
});
