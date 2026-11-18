const leadStatuses = ['new', 'contacted', 'follow_up', 'converted', 'lost'];
const leadPriorities = ['low', 'medium', 'high', 'hot'];
const leadSources = [
  'manual', 'facebook', 'instagram', 'whatsapp', 'messenger', 'walk_in', 'call', 'csv'
];

/// The follow-up lists for the TV repair business.
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

const incomeCategories = [
  'Repair charges',
  'Service visit',
  'Parts sale',
  'Advance received',
  'Motherboard repair',
  'Panel repair',
  'Backlight replacement',
  'Other',
];

const expenseCategories = [
  'Spare parts',
  'LED Backlight strips',
  'Motherboard/Board',
  'Panel parts',
  'Salary / advance',
  'Shop rent',
  'Transport / Fuel',
  'Tea / food',
  'Electricity',
  'Tools & equipment',
  'Other',
];

const payModes = ['cash', 'upi', 'card', 'bank'];

/// Common TV brands for quick selection in the TV repair CRM.
const commonTvBrands = [
  'Samsung',
  'LG',
  'Sony',
  'Mi / Xiaomi',
  'OnePlus',
  'TCL',
  'Panasonic',
  'Vu',
  'Haier',
  'Toshiba',
  'Realme',
  'Micromax',
  'Sansui',
  'Thomson',
  'Hisense',
  'Intex',
  'Other',
];

/// Common TV problems / repair complaints.
const commonTvIssues = [
  'No display (Sound OK / Backlight issue)',
  'Dead TV (No power / No LED indicator)',
  'Lines on screen / Panel display issue',
  'Half screen dark / Dim screen',
  'Double image / Flickering picture',
  'Sound problem (No audio / Distorted sound)',
  'Smart TV boot loop / Stuck on logo',
  'HDMI / USB / AV port not working',
  'Wi-Fi / Remote connection problem',
  'Screen cracked / Panel damage',
  'Auto turn off / Restarting repeatedly',
  'General service / Inspection',
];

/// TV screen sizes
const commonScreenSizes = [
  '24"', '32"', '40"', '43"', '48"', '50"', '55"', '65"', '75"+',
];

/// Attendance rules
const shiftStartHour = 10;
const shiftStartMinute = 0;
const lateGraceMinutes = 15;

/// How often (minutes) location is saved while an employee is checked in.
const locationIntervalMinutes = 5;
