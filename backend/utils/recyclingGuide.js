/**
 * Curated sorting guidance. General best practice, deliberately not phrased as
 * municipal rules: bin colours and accepted items vary by emirate and operator.
 */
export const GUIDE = [
  {
    key: "plastic_bottle",
    name: "Plastic bottle",
    material: "Plastic (PET)",
    keywords: ["plastic bottle", "water bottle", "pet", "soda bottle", "juice bottle", "bottle"],
    bin: "Recycling: plastics",
    binColor: "#3B82C4",
    prep: ["Empty and rinse", "Squash to save space", "Keep the cap on"],
    placeTypes: ["Recycling Bin", "Recycling Centre"],
    tip: "A refillable bottle at a water refill point avoids the plastic altogether.",
    points: true,
  },
  {
    key: "can",
    name: "Drink can",
    material: "Aluminium",
    keywords: ["can", "aluminium", "aluminum", "soda can", "tin"],
    bin: "Recycling: cans and metal",
    binColor: "#8A8F98",
    prep: ["Empty and rinse", "Do not crush if your bin uses a can sorter"],
    placeTypes: ["Recycling Bin", "Recycling Centre"],
    tip: "Aluminium can be recycled again and again without losing quality.",
    points: true,
  },
  {
    key: "glass",
    name: "Glass jar or bottle",
    material: "Glass",
    keywords: ["glass", "jar", "wine bottle", "glass bottle"],
    bin: "Recycling: glass",
    binColor: "#2A9D8F",
    prep: ["Empty and rinse", "Remove metal lids and recycle them with cans"],
    placeTypes: ["Recycling Centre", "Recycling Bin"],
    tip: "Broken glass and mirrors usually go in general waste, wrapped safely.",
    points: true,
  },
  {
    key: "paper",
    name: "Paper and cardboard",
    material: "Paper / cardboard",
    keywords: ["paper", "cardboard", "carton", "box", "newspaper", "magazine", "delivery box"],
    bin: "Recycling: paper and cardboard",
    binColor: "#C9A227",
    prep: ["Flatten boxes", "Keep it dry", "Remove tape and plastic windows if you can"],
    placeTypes: ["Recycling Bin", "Recycling Centre"],
    tip: "Wet or food-stained paper can't be recycled.",
    points: true,
  },
  {
    key: "pizza_box",
    name: "Greasy pizza box",
    material: "Food-soiled cardboard",
    keywords: ["pizza", "pizza box", "greasy"],
    bin: "Split it: clean lid to recycling, greasy base to general waste",
    binColor: "#C9A227",
    prep: ["Tear off the clean top", "Put the oily part in general waste"],
    placeTypes: ["Recycling Bin"],
    tip: "Grease contaminates paper recycling, so separating the clean part matters.",
    points: false,
  },
  {
    key: "battery",
    name: "Batteries",
    material: "Hazardous: batteries",
    keywords: ["battery", "batteries", "aa", "aaa", "power bank", "lithium"],
    bin: "Never in household bins. Take to an e-waste drop-off.",
    binColor: "#C2413B",
    prep: ["Tape the terminals of lithium batteries", "Store in a dry container until drop-off"],
    placeTypes: ["E-waste Drop-off"],
    tip: "Lithium batteries in rubbish trucks can start fires.",
    points: true,
  },
  {
    key: "ewaste",
    name: "Electronics",
    material: "E-waste",
    keywords: ["phone", "laptop", "charger", "cable", "electronic", "electronics", "tablet", "headphones", "mouse", "keyboard"],
    bin: "E-waste drop-off",
    binColor: "#7A5CC2",
    prep: ["Back up and wipe personal data", "Remove batteries if possible", "Keep cables together"],
    placeTypes: ["E-waste Drop-off"],
    tip: "Working devices can often be donated instead.",
    points: true,
  },
  {
    key: "plastic_bag",
    name: "Plastic bag or film",
    material: "Soft plastic",
    keywords: ["plastic bag", "bag", "wrap", "film", "cling"],
    bin: "Usually not accepted in household recycling. Use a store take-back point.",
    binColor: "#8A8F98",
    prep: ["Keep clean and dry", "Bundle bags together"],
    placeTypes: ["Recycling Centre"],
    tip: "Soft plastics jam sorting machines, so keep them out of the plastics bin unless it says otherwise.",
    points: false,
  },
  {
    key: "coffee_cup",
    name: "Takeaway coffee cup",
    material: "Paper with plastic lining",
    keywords: ["coffee cup", "takeaway cup", "paper cup", "cup"],
    bin: "General waste in most areas (the lining makes it hard to recycle)",
    binColor: "#6E6578",
    prep: ["Lids may go with plastics if marked recyclable"],
    placeTypes: [],
    tip: "Bring a reusable cup: many cafes offer a small discount.",
    points: false,
  },
  {
    key: "food",
    name: "Food waste",
    material: "Organic",
    keywords: ["food", "fruit", "vegetable", "peel", "leftovers", "organic", "compost"],
    bin: "Organic or general waste. Compost at home if you can.",
    binColor: "#7FA33A",
    prep: ["Drain liquids", "Keep out of recycling bins"],
    placeTypes: [],
    tip: "Composting turns food scraps into soil for community gardens.",
    points: false,
  },
  {
    key: "textiles",
    name: "Clothes and textiles",
    material: "Textiles",
    keywords: ["clothes", "clothing", "shirt", "shoes", "textile", "fabric"],
    bin: "Donation or textile collection point",
    binColor: "#B0577C",
    prep: ["Wash and bag them", "Pair shoes together"],
    placeTypes: ["Recycling Centre"],
    tip: "Good-condition clothes do more good donated than recycled.",
    points: false,
  },
];

export const findGuide = (text) => {
  const q = String(text || "").toLowerCase();
  if (!q) return null;
  let best = null;
  let bestLen = 0;
  for (const g of GUIDE) {
    for (const k of g.keywords) {
      if (q.includes(k) && k.length > bestLen) {
        best = g;
        bestLen = k.length;
      }
    }
  }
  return best;
};

export const guideByKey = (key) => GUIDE.find((g) => g.key === key) || null;
