function canEditTestSchedule({ status, hasAttempts }) {
  // An administrator may move a published test to a new future time if no
  // student has started it. The student API re-evaluates startTime and keeps
  // the test locked until that newly published start time.
  return status !== 'closed' && !hasAttempts;
}

module.exports = { canEditTestSchedule };
