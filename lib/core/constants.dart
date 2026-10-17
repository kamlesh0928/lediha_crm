const leadStatuses = ['new', 'contacted', 'follow_up', 'converted', 'lost'];
const leadPriorities = ['low', 'medium', 'high', 'hot'];
const leadSources = [
  'manual', 'facebook', 'instagram', 'whatsapp', 'messenger', 'walk_in', 'call', 'csv'
];

/// The follow-up lists the client asked for (plus a general one).
const followupKinds = ['hot_lead', 'pickup', 'work_pending', 'work_done', 'delivery', 'general'];
const followupKindLabels = {
  'hot_lead': 'Hot lead',
  'pickup': "Today's pickup",
  'work_pending': 'Work pending',
  'work_done': 'Work done',
  'delivery': 'Delivery',
  'general': 'General',
};

const taskStatuses = ['pending', 'in_progress', 'completed', 'reopened'];

const incomeCategories = ['Repair charges', 'Service visit', 'Parts sale', 'Advance received', 'Other'];
const expenseCategories = [
  'Spare parts', 'Salary / advance', 'Shop rent', 'Transport', 'Tea / food', 'Electricity', 'Other'
];
const payModes = ['cash', 'upi', 'card', 'bank'];

/// Attendance rules (move these into a settings table later if the client wants to edit them).
const shiftStartHour = 10;
const shiftStartMinute = 0;
const lateGraceMinutes = 15;

/// How often (minutes) location is saved while an employee is checked in.
const locationIntervalMinutes = 5;
