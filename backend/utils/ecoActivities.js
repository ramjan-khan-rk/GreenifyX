/**
 * Built-in eco activities. Inserted once (by key) so admins can then edit,
 * disable or add more from the admin panel without being overwritten.
 * co2Kg = indicative CO2e saved per action (planning estimate, not MRV).
 */
export const DEFAULT_ACTIVITIES = [
  // Planet — trees & nature
  ["planted-a-tree", "Planted a Tree", "زرعت شجرة", "Planet", "A new life, in the ground", "park", 50, 21, ["tree", "planting", "ghaf", "sapling", "greening", "forest"]],
  ["mangrove-planting", "Planted Mangroves", "زراعة القرم", "Planet", "Coastal trees that store blue carbon", "water", 60, 25, ["mangrove", "qurm", "coast", "blue carbon", "planting"]],
  ["home-garden", "Grew Food at Home", "زراعة منزلية", "Planet", "Herbs, veg or a balcony garden", "yard", 20, 1.5, ["garden", "herbs", "vegetables", "balcony", "grow", "home farming"]],
  ["composting", "Composted Food Waste", "صنعت سماداً", "Planet", "Scraps turned into soil", "compost", 25, 2.5, ["compost", "food waste", "organic", "soil", "kitchen scraps"]],
  // Planet — waste
  ["recycling", "Recycled Properly", "أعدت التدوير", "Planet", "Sorted and dropped at the right bin", "recycling", 20, 2, ["recycle", "plastic", "paper", "cans", "bottles", "sorting", "bin"]],
  ["e-waste", "Dropped Off E-waste", "سلمت نفايات إلكترونية", "Planet", "Old phones, cables, batteries", "devices_other", 30, 5, ["e-waste", "electronics", "battery", "phone", "cables", "laptop"]],
  ["refill-not-plastic", "Refilled, No Plastic", "أعدت التعبئة", "Planet", "Reusable bottle or cup instead of single-use", "water_drop", 15, 0.3, ["refill", "reusable", "bottle", "cup", "single-use", "plastic free"]],
  ["reusable-bags", "Used Reusable Bags", "حقائب قابلة لإعادة الاستخدام", "Planet", "Said no to plastic bags", "shopping_bag", 10, 0.1, ["bag", "tote", "shopping", "plastic bag", "reusable"]],
  ["gave-it-another-life", "Gave It Another Life", "منحته حياة أخرى", "Planet", "Repaired, upcycled or donated", "autorenew", 20, 2, ["upcycle", "repair", "donate", "second hand", "thrift", "reuse"]],
  ["zero-waste-meal", "Zero-Waste Meal", "وجبة بلا هدر", "Planet", "Cooked leftovers, wasted nothing", "restaurant", 15, 1, ["leftovers", "food waste", "zero waste", "meal", "cooking"]],
  ["cleaned-a-corner", "Cleaned a Corner", "نظفت مكاناً", "Planet", "Left a place better than you found it", "cleaning_services", 40, 3, ["clean up", "litter", "park", "street", "pick up"]],
  ["beach-cleanup", "Beach Clean-up", "تنظيف الشاطئ", "Planet", "Plastic off the sand, before it reaches the sea", "beach_access", 50, 4, ["beach", "coast", "plastic", "litter", "sea", "clean up"]],
  ["desert-cleanup", "Desert Clean-up", "تنظيف الصحراء", "Planet", "Kept the dunes clean after camping", "landscape", 45, 3, ["desert", "dunes", "camping", "litter", "clean up"]],
  ["dive-cleanup", "Reef or Dive Clean-up", "تنظيف الشعاب", "Wildlife", "Nets and plastic lifted off the reef", "scuba_diving", 60, 4, ["dive", "reef", "coral", "nets", "underwater", "snorkel"]],
  // Planet — transport & energy
  ["rode-instead", "Cycled Instead of Driving", "ركبت الدراجة", "Planet", "Two wheels, and the day opened up", "pedal_bike", 15, 1.2, ["cycling", "bike", "bicycle", "commute", "ride"]],
  ["walked-today", "Walked Instead of Driving", "مشيت بدل القيادة", "Planet", "The long way, on purpose", "directions_walk", 10, 0.6, ["walk", "walking", "steps", "commute"]],
  ["public-transport", "Took Metro or Bus", "استخدمت المواصلات العامة", "Planet", "Shared the ride, cut the traffic", "directions_subway", 15, 1.5, ["metro", "bus", "tram", "nol", "public transport", "commute"]],
  ["carpool", "Carpooled", "شاركت السيارة", "Planet", "One car, more people", "groups", 12, 1.8, ["carpool", "ride share", "shared ride", "commute"]],
  ["saved-energy", "Saved Energy at Home", "وفرت الطاقة", "Planet", "AC at 24°C, lights off, unplugged", "bolt", 15, 1, ["energy", "electricity", "ac", "lights", "dewa", "addc", "unplug"]],
  ["solar", "Used Solar Power", "استخدمت الطاقة الشمسية", "Planet", "Sunlight doing the work", "solar_power", 30, 3, ["solar", "panel", "renewable", "sun", "clean energy"]],
  ["protected-water", "Saved Water", "حافظت على المياه", "Planet", "Shorter shower, fixed a leak", "water", 20, 0.4, ["water", "shower", "leak", "tap", "save water", "irrigation"]],
  // Humanity
  ["stood-for-someone", "Stood for Someone", "ساندت أحداً", "Humanity", "One person, fully", "volunteer_activism", 25, 0, ["help", "volunteer", "support", "kindness"]],
  ["shared-a-table", "Shared a Table", "شاركت الطعام", "Humanity", "Food, time, or a safe seat", "dinner_dining", 25, 0.5, ["food", "iftar", "share", "meal", "food bank"]],
  ["donated-clothes", "Donated Clothes", "تبرعت بالملابس", "Humanity", "Wardrobe to someone who needs it", "checkroom", 20, 3, ["clothes", "donate", "textile", "charity", "kiswa"]],
  ["taught-eco", "Taught Someone Green Habits", "علمت عادات خضراء", "Humanity", "Passed the habit on", "school", 20, 0, ["teach", "awareness", "school", "kids", "workshop"]],
  // Wildlife
  ["cared-for-a-life", "Cared for an Animal", "اعتنيت بحيوان", "Wildlife", "An animal got what it needed", "pets", 25, 0, ["animal", "rescue", "pet", "stray", "cat", "vet"]],
  ["made-room-for-them", "Made Room for Wildlife", "أفسحت للحياة البرية", "Wildlife", "Space given back", "forest", 20, 0, ["wildlife", "habitat", "nest", "turtle", "reserve"]],
  ["bird-water", "Left Water for Birds", "وضعت ماء للطيور", "Wildlife", "A bowl of water in the summer heat", "flutter_dash", 10, 0, ["birds", "water bowl", "summer", "heat"]],
  // Stories
  ["after-the-good", "After the Good", "بعد الخير", "Stories", "How it felt once you helped", "favorite", 15, 0, ["story", "feeling", "reflection"]],
  ["a-quiet-win", "A Quiet Win", "إنجاز هادئ", "Stories", "Small, and still worth telling", "emoji_events", 10, 0, ["small win", "habit", "everyday"]],
].map(([key, name, nameAr, lane, line, icon, points, co2Kg, keywords], i) => ({
  key, name, nameAr, lane, line, icon, points, co2Kg, keywords, order: i * 10,
}));

// Names used by older app versions → current keys, so old posts still score.
export const LEGACY_NAMES = {
  "Tree Plantation": "planted-a-tree",
  Recycling: "recycling",
  Cycling: "rode-instead",
  Walk: "walked-today",
  "Cleanliness Drive": "cleaned-a-corner",
  "Water Conservation": "protected-water",
  "Rode Instead": "rode-instead",
  "Walked Today": "walked-today",
  "Protected Water": "protected-water",
  "Made Room for Them": "made-room-for-them",
  "Cared for a Life": "cared-for-a-life",
};

/** Lower-case words of a search, matched against name, line and keywords. */
export const matchesQuery = (a, q) => {
  const words = String(q || "").toLowerCase().split(/\s+/).filter(Boolean);
  if (!words.length) return true;
  const hay = [a.name, a.nameAr, a.line, ...(a.keywords || [])].join(" ").toLowerCase();
  return words.every((w) => hay.includes(w));
};

/** Slug for a new activity key. */
export const slugify = (s) =>
  String(s || "").toLowerCase().trim().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 60);

// ---- In-memory lookup (refreshed from the database) ----
const byName = new Map();
const byKey = new Map();

export const cacheActivities = (list) => {
  byName.clear();
  byKey.clear();
  for (const a of list) {
    byName.set(a.name, a);
    byKey.set(a.key, a);
  }
};
cacheActivities(DEFAULT_ACTIVITIES);

/** Find an activity by its name (what posts store), key or legacy name. */
export const findActivity = (nameOrKey) => {
  const v = String(nameOrKey || "").trim();
  return byName.get(v) || byKey.get(v) || byKey.get(LEGACY_NAMES[v]) || null;
};

/** Insert built-ins that are missing, then refresh the cache. */
export const syncActivities = async () => {
  const { default: EcoActivity } = await import("../models/EcoActivity.js");
  for (const a of DEFAULT_ACTIVITIES) {
    await EcoActivity.updateOne({ key: a.key }, { $setOnInsert: a }, { upsert: true });
  }
  cacheActivities(await EcoActivity.find().lean());
};
