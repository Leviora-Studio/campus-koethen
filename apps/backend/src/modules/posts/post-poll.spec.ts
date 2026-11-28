import { localizedPoll, parsePostPoll } from './post-poll';

const demoPoll = {
  key: 'demo-poll',
  question: 'Demo question?',
  options: [
    { key: 'first', label: 'First' },
    { key: 'second', label: 'Second' },
  ],
};

describe('editorial post polls', () => {
  it('keeps stable identifiers while accepting translated labels and question', () => {
    const en = {
      ...demoPoll,
      question: 'Translated?',
      options: [
        { key: 'second', label: 'Two' },
        { key: 'first', label: 'One' },
      ],
    };
    expect(localizedPoll(demoPoll, en)).toEqual({
      key: 'demo-poll',
      question: 'Translated?',
      options: [
        { key: 'first', label: 'One' },
        { key: 'second', label: 'Two' },
      ],
    });
  });

  it('rejects duplicate option keys and ignores incompatible translations', () => {
    expect(
      parsePostPoll({ ...demoPoll, options: [demoPoll.options[0], demoPoll.options[0]] }),
    ).toBeNull();
    expect(localizedPoll(demoPoll, { ...demoPoll, key: 'different' })).toEqual(demoPoll);
    expect(localizedPoll(null, demoPoll)).toBeNull();
  });
});
