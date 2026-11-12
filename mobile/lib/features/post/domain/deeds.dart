class Deed {
  final String lane;
  final String name;
  final String line;

  const Deed(this.lane, this.name, this.line);
}

const deedLanes = ["Planet", "Humanity", "Wildlife", "Stories"];

const deeds = <Deed>[
  Deed("Planet", "Planted a Tree", "A new life, in the ground"),
  Deed("Planet", "Gave It Another Life", "Used again, not thrown away"),
  Deed("Planet", "Rode Instead", "Two wheels, and the day opened up"),
  Deed("Planet", "Walked Today", "The long way, on purpose"),
  Deed("Planet", "Cleaned a Corner", "Left a place better than you found it"),
  Deed("Planet", "Protected Water", "Kept something precious"),
  Deed("Humanity", "Stood for Someone", "One person, fully"),
  Deed("Humanity", "Shared a Table", "Food, time, or a safe seat"),
  Deed("Wildlife", "Cared for a Life", "An animal got what it needed"),
  Deed("Wildlife", "Made Room for Them", "Space given back"),
  Deed("Stories", "After the Good", "How it felt once you helped"),
  Deed("Stories", "A Quiet Win", "Small, and still worth telling"),
];
