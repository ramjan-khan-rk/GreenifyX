/**
 * Eco Academy: one 60-second lesson a day, with a 3-question quiz.
 * General best practice for the UAE, not official municipal rules.
 * Each quiz item: { q, options: [3], answer: index, why }.
 */
export const LESSONS = [
  {
    id: "recycling-basics",
    emoji: "♻️",
    title: "Recycling that actually gets recycled",
    cards: [
      "Recycling only works when items are clean and dry. Food and liquid can spoil a whole bag of paper or plastic.",
      "Give bottles and tins a quick rinse, squash them to save space, and keep caps on unless your bin says otherwise.",
      "When you're not sure, check the label on the bin. Putting the wrong thing in (\"wish-cycling\") makes sorting harder.",
    ],
    quiz: [
      { q: "What can spoil a bag of recyclables?", options: ["Food and liquid", "Squashed bottles", "Clean paper"], answer: 0, why: "Leftover food and drinks contaminate paper and plastic." },
      { q: "Before recycling a drinks bottle you should…", options: ["Fill it with sand", "Rinse and squash it", "Wrap it in a bag"], answer: 1, why: "A quick rinse and squash keeps the stream clean and saves space." },
      { q: "\"Wish-cycling\" means…", options: ["Recycling on your birthday", "Putting things in hoping they're recyclable", "Recycling only glass"], answer: 1, why: "Guessing adds the wrong items and makes sorting harder. Check the bin label." },
    ],
  },
  {
    id: "desalination",
    emoji: "💧",
    title: "Why every drop counts here",
    cards: [
      "Much of the UAE's drinking water comes from desalinating seawater, which takes a lot of energy.",
      "So saving water at home also saves energy, and the emissions that come with it.",
      "Easy wins: fix dripping taps, take shorter showers, and run the washing machine and dishwasher only when full.",
    ],
    quiz: [
      { q: "Much of the UAE's drinking water comes from…", options: ["Glaciers", "Desalinated seawater", "Rainwater only"], answer: 1, why: "Desalination plants turn seawater into drinking water." },
      { q: "Saving water at home also saves…", options: ["Energy", "Nothing else", "Sand"], answer: 0, why: "Desalinating and pumping water uses a lot of energy." },
      { q: "Which is an easy water win?", options: ["Fixing a dripping tap", "Running a half-full dishwasher", "Longer showers"], answer: 0, why: "A dripping tap wastes water all day and night." },
    ],
  },
  {
    id: "smart-ac",
    emoji: "❄️",
    title: "Cool home, lower bill",
    cards: [
      "Air conditioning is one of the biggest uses of electricity in UAE homes.",
      "Setting the thermostat around 24°C instead of very low keeps you comfortable and uses noticeably less power.",
      "Close curtains on sunny windows, clean AC filters regularly and switch off cooling in empty rooms.",
    ],
    quiz: [
      { q: "A sensible AC setting is around…", options: ["16°C", "24°C", "30°C"], answer: 1, why: "Around 24°C balances comfort and energy use." },
      { q: "Dirty AC filters…", options: ["Make the AC work harder", "Save energy", "Don't matter"], answer: 0, why: "Clogged filters reduce airflow, so the unit uses more power." },
      { q: "Closing curtains on sunny windows…", options: ["Heats the room", "Keeps heat out", "Has no effect"], answer: 1, why: "Blocking direct sun reduces the heat your AC must remove." },
    ],
  },
  {
    id: "ghaf",
    emoji: "🌳",
    title: "The Ghaf, our national tree",
    cards: [
      "The Ghaf is the UAE's national tree. It survives the desert thanks to very deep roots that reach underground water.",
      "Its shade and branches shelter birds, insects and animals, and it helps hold sand in place.",
      "Native trees like the Ghaf need far less watering than many imported plants once they're established.",
    ],
    quiz: [
      { q: "The Ghaf survives the desert mainly because of…", options: ["Deep roots", "Big leaves", "Daily rain"], answer: 0, why: "Its roots reach deep groundwater." },
      { q: "The Ghaf is the UAE's…", options: ["National flower", "National tree", "National fruit"], answer: 1, why: "It was named the national tree." },
      { q: "Compared with many imported plants, established native trees need…", options: ["More water", "Less water", "Only sea water"], answer: 1, why: "They're adapted to the local climate." },
    ],
  },
  {
    id: "mangroves",
    emoji: "🌿",
    title: "Mangroves: coastal superheroes",
    cards: [
      "Mangroves grow in salty coastal water. Their roots protect shorelines from waves and erosion.",
      "They store large amounts of carbon in their roots and the mud below, often called \"blue carbon\".",
      "They're also nurseries for young fish and home to many birds. Abu Dhabi has well-known mangrove areas you can visit by kayak.",
    ],
    quiz: [
      { q: "Mangrove roots help…", options: ["Protect the coast", "Heat the sea", "Make sand"], answer: 0, why: "They slow waves and hold soil in place." },
      { q: "\"Blue carbon\" is carbon stored by…", options: ["Coastal ecosystems like mangroves", "Blue cars", "The sky"], answer: 0, why: "Mangroves and seagrass lock carbon in their mud." },
      { q: "Mangroves are nurseries for…", options: ["Young fish", "Camels", "Cacti"], answer: 0, why: "Their sheltered roots protect young marine life." },
    ],
  },
  {
    id: "food-waste",
    emoji: "🍽️",
    title: "Waste less food",
    cards: [
      "Food that rots in a landfill gives off methane, a gas that warms the planet much faster than CO₂ in the short term.",
      "Plan meals, check your fridge before shopping, and store leftovers in clear boxes so you see them.",
      "\"Best before\" is about quality; \"use by\" is about safety. Many \"best before\" foods are fine a little after the date.",
    ],
    quiz: [
      { q: "Food rotting in a landfill releases…", options: ["Methane", "Oxygen", "Helium"], answer: 0, why: "Without air, food breaks down into methane." },
      { q: "\"Use by\" dates are about…", options: ["Safety", "Colour", "Price"], answer: 0, why: "Don't eat food after its use-by date." },
      { q: "A simple way to waste less food is…", options: ["Shopping without a list", "Checking the fridge first", "Cooking double every day"], answer: 1, why: "Knowing what you have avoids buying extra." },
    ],
  },
  {
    id: "single-use",
    emoji: "🛍️",
    title: "Break up with single-use plastic",
    cards: [
      "Several emirates now restrict single-use plastic bags, and reusable bags are the easy answer.",
      "Keep a foldable bag in your car or backpack, and carry a refillable bottle and cup.",
      "Saying \"no straw, no cutlery, thanks\" when ordering food adds up fast.",
    ],
    quiz: [
      { q: "The easiest swap for plastic bags is…", options: ["A reusable bag", "Two plastic bags", "A paper cup"], answer: 0, why: "A reusable bag replaces hundreds of single-use ones." },
      { q: "When ordering delivery you can…", options: ["Ask for extra cutlery", "Skip cutlery you don't need", "Order more sauces"], answer: 1, why: "Unused plastic cutlery is pure waste." },
      { q: "Carrying a refillable bottle helps because…", options: ["It replaces disposable bottles", "It's heavier", "It needs batteries"], answer: 0, why: "Every refill is one less disposable bottle." },
    ],
  },
  {
    id: "e-waste",
    emoji: "🔋",
    title: "Batteries and old phones",
    cards: [
      "Batteries and electronics contain materials that are hazardous in a general bin but valuable when recovered.",
      "Never throw batteries in household rubbish. They can leak, and some can start fires in bin lorries.",
      "Use e-waste collection points at malls and electronics shops, and wipe your data before handing in a phone.",
    ],
    quiz: [
      { q: "Old batteries should go…", options: ["In the general bin", "To an e-waste collection point", "Down the drain"], answer: 1, why: "They need special handling and can be recovered." },
      { q: "Why are batteries risky in rubbish?", options: ["They can leak or start fires", "They're too light", "They smell"], answer: 0, why: "Damaged batteries can overheat." },
      { q: "Before recycling a phone you should…", options: ["Wipe your data", "Paint it", "Freeze it"], answer: 0, why: "Protect your privacy first." },
    ],
  },
  {
    id: "move-greener",
    emoji: "🚇",
    title: "Move around greener",
    cards: [
      "Burning petrol or diesel releases CO₂. Short car trips are some of the least efficient.",
      "For short trips, walk or cycle when it's cool. For longer ones, try the metro, tram or bus.",
      "Sharing a ride splits the emissions between everyone in the car.",
    ],
    quiz: [
      { q: "Burning petrol releases…", options: ["CO₂", "Pure oxygen", "Water only"], answer: 0, why: "Fuel combustion produces carbon dioxide." },
      { q: "A greener choice for a 1 km trip on a cool evening is…", options: ["Walking", "Driving alone", "Idling the car"], answer: 0, why: "Walking short distances has no tailpipe emissions." },
      { q: "Carpooling…", options: ["Splits emissions between riders", "Doubles them", "Changes nothing"], answer: 0, why: "One car, several people, less CO₂ each." },
    ],
  },
  {
    id: "home-energy",
    emoji: "💡",
    title: "Small switches, big savings",
    cards: [
      "LED bulbs use a fraction of the electricity of old incandescent bulbs and last many times longer.",
      "Chargers, TVs and consoles on standby keep drawing power. Switch off at the wall when you can.",
      "Running the washing machine on a cooler cycle saves energy and is gentler on clothes.",
    ],
    quiz: [
      { q: "Compared with old bulbs, LEDs use…", options: ["Much less electricity", "More electricity", "The same"], answer: 0, why: "LEDs are far more efficient." },
      { q: "Devices on standby…", options: ["Use no power", "Still draw some power", "Make power"], answer: 1, why: "Standby power adds up over a year." },
      { q: "A cooler wash cycle…", options: ["Saves energy", "Uses more energy", "Breaks the machine"], answer: 0, why: "Heating water is most of a wash's energy." },
    ],
  },
  {
    id: "oryx",
    emoji: "🦌",
    title: "The comeback of the Arabian oryx",
    cards: [
      "The Arabian oryx once disappeared from the wild because of hunting.",
      "Breeding programmes, including in the UAE, brought it back, and it now roams protected reserves again.",
      "It shows that protecting habitats and stopping hunting can bring a species back from the brink.",
    ],
    quiz: [
      { q: "The Arabian oryx nearly vanished because of…", options: ["Hunting", "Too much rain", "Traffic lights"], answer: 0, why: "Hunting wiped out the wild population." },
      { q: "It came back thanks to…", options: ["Breeding and protection", "Luck alone", "Zoos closing"], answer: 0, why: "Captive breeding and reintroduction into reserves." },
      { q: "The lesson of the oryx is that…", options: ["Protection can work", "Nothing can be done", "Deserts are empty"], answer: 0, why: "Conservation brought it back." },
    ],
  },
  {
    id: "sea-life",
    emoji: "🐢",
    title: "Protect our sea life",
    cards: [
      "The Gulf is home to sea turtles and dugongs. Abu Dhabi's waters hold one of the world's largest dugong populations.",
      "Turtles can mistake floating plastic bags for jellyfish, which harms them.",
      "Take all rubbish home from the beach, and join a beach clean-up to make a visible difference.",
    ],
    quiz: [
      { q: "Turtles may confuse plastic bags with…", options: ["Jellyfish", "Rocks", "Boats"], answer: 0, why: "Floating bags look like their food." },
      { q: "Which gentle sea mammal lives in UAE waters?", options: ["Dugong", "Polar bear", "Penguin"], answer: 0, why: "Dugongs graze on seagrass in the Gulf." },
      { q: "The best thing to do with beach rubbish is…", options: ["Bury it in the sand", "Take it home or bin it", "Leave it for the tide"], answer: 1, why: "Buried rubbish often washes out to sea." },
    ],
  },
  {
    id: "fashion",
    emoji: "👕",
    title: "Clothes that last",
    cards: [
      "Making new clothes uses a lot of water, energy and chemicals.",
      "Wearing what you own for longer is the greenest choice: repair, swap, or buy second hand.",
      "Donate clothes that are clean and wearable. Worn-out textiles can often go to textile recycling bins.",
    ],
    quiz: [
      { q: "The greenest clothing choice is usually…", options: ["Wearing what you own longer", "Buying new every month", "Throwing clothes away"], answer: 0, why: "Every extra wear spreads the impact of making it." },
      { q: "A good option for clothes you no longer wear is…", options: ["Donating or swapping", "The general bin", "Burning them"], answer: 0, why: "Someone else gets to wear them." },
      { q: "A small hole in a shirt means…", options: ["Repair it", "Bin it", "Buy two more"], answer: 0, why: "Simple repairs add years of life." },
    ],
  },
  {
    id: "carbon-basics",
    emoji: "🌍",
    title: "What is a carbon footprint?",
    cards: [
      "Gases like CO₂ trap heat in the atmosphere. Burning fossil fuels for power, cars and industry releases most of it.",
      "Your carbon footprint adds up the emissions from your energy, travel, food and the things you buy.",
      "You can't do everything, but a few steady habits, like cooling, travel and waste, make the biggest difference.",
    ],
    quiz: [
      { q: "CO₂ in the atmosphere…", options: ["Traps heat", "Cools the planet", "Has no effect"], answer: 0, why: "It's a greenhouse gas." },
      { q: "Most CO₂ comes from…", options: ["Burning fossil fuels", "Trees", "Oceans freezing"], answer: 0, why: "Power, transport and industry burn coal, oil and gas." },
      { q: "A carbon footprint includes…", options: ["Energy, travel, food and shopping", "Only flights", "Only food"], answer: 0, why: "It adds up everything you use and do." },
    ],
  },
];

export const LESSON_POINTS = 5;
export const PASS_MARK = 2;

/** Today's lesson rotates through the library by UAE day. */
export const lessonForDay = (dayStamp) => {
  const n = Math.round(Date.parse(`${dayStamp}T00:00:00Z`) / 864e5);
  return LESSONS[((n % LESSONS.length) + LESSONS.length) % LESSONS.length];
};

export const lessonById = (id) => LESSONS.find((l) => l.id === id) || null;

/** The lesson without answers, for the app. */
export const publicLesson = (l) => ({
  id: l.id,
  emoji: l.emoji,
  title: l.title,
  cards: l.cards,
  quiz: l.quiz.map((x) => ({ q: x.q, options: x.options })),
});

/** Mark answers; returns per-question results and the score. */
export const markQuiz = (lesson, answers = []) => {
  const results = lesson.quiz.map((x, i) => ({ correct: Number(answers[i]) === x.answer, answer: x.answer, why: x.why }));
  const score = results.filter((r) => r.correct).length;
  return { results, score, passed: score >= PASS_MARK };
};

/** Consecutive UAE days ending today or yesterday. days: ["YYYY-MM-DD", ...]. */
export const currentStreak = (days = [], today) => {
  const set = new Set(days);
  const step = (d, k) => new Date(Date.parse(`${d}T00:00:00Z`) + k * 864e5).toISOString().slice(0, 10);
  let cursor = set.has(today) ? today : step(today, -1);
  let n = 0;
  while (set.has(cursor)) {
    n++;
    cursor = step(cursor, -1);
  }
  return n;
};
