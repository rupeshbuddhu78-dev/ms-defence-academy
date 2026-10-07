const StudentProfile = require('../models/StudentProfile');
const StudentIdCounter = require('../models/StudentIdCounter');

const COUNTER_ID = 'studentId';

function isDuplicateKey(error) {
  return error && (error.code === 11000 || error.codeName === 'DuplicateKey');
}

function createStudentIdAllocator({ StudentProfileModel, CounterModel }) {
  return async function reserveStudentId() {
    const profiles = await StudentProfileModel.find({ studentId: /^MSDA\d+$/i })
      .select('studentId')
      .lean();
    const highest = profiles.reduce((max, profile) => {
      const value = Number(String(profile.studentId).replace(/^MSDA/i, ''));
      return Number.isSafeInteger(value) ? Math.max(max, value) : max;
    }, 0);

    try {
      await CounterModel.updateOne(
        { _id: COUNTER_ID },
        { $max: { value: highest } },
        { upsert: true, setDefaultsOnInsert: false },
      );
    } catch (error) {
      // Two first-time callers may race to create the counter document. The _id
      // index chooses one winner; the loser synchronizes against the winner.
      if (!isDuplicateKey(error)) throw error;
      await CounterModel.updateOne(
        { _id: COUNTER_ID },
        { $max: { value: highest } },
      );
    }

    const counter = await CounterModel.findOneAndUpdate(
      { _id: COUNTER_ID },
      { $inc: { value: 1 } },
      { new: true },
    ).lean();
    if (!counter || !Number.isSafeInteger(counter.value)) {
      throw new Error('Student ID counter could not reserve a valid sequence');
    }
    return `MSDA${String(counter.value).padStart(2, '0')}`;
  };
}

const reserveStudentId = createStudentIdAllocator({
  StudentProfileModel: StudentProfile,
  CounterModel: StudentIdCounter,
});
reserveStudentId.createStudentIdAllocator = createStudentIdAllocator;

module.exports = reserveStudentId;
