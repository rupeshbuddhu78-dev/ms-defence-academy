const test = require('node:test');
const assert = require('node:assert/strict');
const { createStudentIdAllocator } = require('../src/services/student-id');

test('shared student ID allocator reserves distinct IDs for concurrent callers', async () => {
  const existingProfiles = [
    { studentId: 'MSDA08' },
    { studentId: 'msda12' },
    { studentId: 'LEGACY-4' },
  ];
  let counter = null;
  const StudentProfileModel = {
    find(filter) {
      assert.match(String(filter.studentId), /MSDA/);
      return {
        select() { return this; },
        async lean() { return existingProfiles; },
      };
    },
  };
  const CounterModel = {
    async updateOne(_filter, update) {
      const floor = update.$max.value;
      if (!counter) counter = { _id: 'studentId', value: floor };
      else counter.value = Math.max(counter.value, floor);
      return { acknowledged: true };
    },
    findOneAndUpdate(_filter, update) {
      return {
        async lean() {
          counter.value += update.$inc.value;
          return { ...counter };
        },
      };
    },
  };
  const reserveStudentId = createStudentIdAllocator({ StudentProfileModel, CounterModel });
  const allocated = await Promise.all(Array.from({ length: 64 }, () => reserveStudentId()));

  assert.equal(new Set(allocated).size, 64);
  assert.equal(Math.min(...allocated.map(id => Number(id.slice(4)))), 13);
  assert.equal(Math.max(...allocated.map(id => Number(id.slice(4)))), 76);
});
