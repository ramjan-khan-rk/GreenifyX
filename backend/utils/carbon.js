/**
 * Personal carbon footprint (kg CO2e per year) from a short questionnaire.
 * Factors are indicative UAE-oriented estimates for awareness, not certified accounting.
 */
export const CARBON_QUESTIONS = {
  carKmPerWeek: { label: "Car travel per week (km)", factor: 52 * 0.19 }, // petrol car ~0.19 kg/km
  carType: { options: { petrol: 1, hybrid: 0.6, electric: 0.3, none: 0 } },
  metroTripsPerWeek: { label: "Metro/bus trips per week", factor: 52 * 0.4 },
  shortFlightsPerYear: { label: "Short flights (< 4h)", factor: 450 },
  longFlightsPerYear: { label: "Long flights", factor: 1800 },
  acHoursPerDay: { label: "AC hours per day at home", factor: 365 * 1.2 * 0.45 }, // ~1.2 kWh/h, UAE grid ~0.45 kg/kWh
  homeSize: { options: { studio: 0.7, apartment: 1, villa: 2.2 } },
  householdSize: { label: "People at home" },
  diet: { options: { vegan: 1100, vegetarian: 1500, "low-meat": 1900, "meat-daily": 2600 } },
  shopping: { options: { minimal: 400, average: 900, high: 1800 } },
  recycles: { options: { always: -150, sometimes: -60, never: 0 } },
};

const num = (v, max = 100000) => Math.max(0, Math.min(max, Number(v) || 0));
const opt = (q, v, fallback) => CARBON_QUESTIONS[q].options[v] ?? CARBON_QUESTIONS[q].options[fallback];

export const computeFootprint = (a = {}) => {
  const people = Math.max(1, Math.round(num(a.householdSize, 20)) || 1);
  const transport =
    num(a.carKmPerWeek, 5000) * CARBON_QUESTIONS.carKmPerWeek.factor * opt("carType", a.carType, "petrol") +
    num(a.metroTripsPerWeek, 100) * CARBON_QUESTIONS.metroTripsPerWeek.factor;
  const flights = num(a.shortFlightsPerYear, 100) * 450 + num(a.longFlightsPerYear, 50) * 1800;
  const home = (num(a.acHoursPerDay, 24) * CARBON_QUESTIONS.acHoursPerDay.factor * opt("homeSize", a.homeSize, "apartment") + 600) / people;
  const food = opt("diet", a.diet, "low-meat");
  const stuff = opt("shopping", a.shopping, "average") + opt("recycles", a.recycles, "never");
  const parts = { transport, flights, home, food, shopping: Math.max(0, stuff) };
  const total = Object.values(parts).reduce((s, v) => s + v, 0);
  const round = (v) => Math.round(v);
  return { totalKg: round(total), parts: Object.fromEntries(Object.entries(parts).map(([k, v]) => [k, round(v)])) };
};

/** UAE average ~ 20 t/person/yr incl. industry; household lifestyle share ~ 9 t. */
export const UAE_LIFESTYLE_AVG_KG = 9000;
export const PARIS_TARGET_KG = 2300;

/** Biggest lever first. */
export const carbonTips = (parts) => {
  const tips = {
    transport: "Swap two car trips a week for metro, bus or cycling — and log them for points.",
    flights: "One fewer long flight a year saves about 1.8 tonnes. Try a staycation in Hatta or Al Ain.",
    home: "Set the AC to 24°C and use timers — each degree saves around 6% of cooling energy.",
    food: "Try two plant-based days a week; it's the easiest food win.",
    shopping: "Repair, swap or buy second-hand on GreenifyX Swap & Share before buying new.",
  };
  return Object.entries(parts).sort((a, b) => b[1] - a[1]).slice(0, 3).map(([k, v]) => ({ area: k, kg: v, tip: tips[k] }));
};
