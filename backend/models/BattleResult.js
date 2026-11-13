import mongoose from "mongoose";

/** Final standings of a finished weekly battle (one row per league per week). */
const battleResultSchema = new mongoose.Schema(
  {
    week: { type: String, required: true }, // e.g. 2026-W46
    league: { type: String, required: true }, // communities | schools | companies | universities | members
    standings: [
      {
        refId: { type: mongoose.Schema.Types.ObjectId },
        name: String,
        image: String,
        points: Number,
        members: Number,
        rank: Number,
      },
    ],
    rewardedAt: { type: Date },
  },
  { timestamps: true }
);

battleResultSchema.index({ week: 1, league: 1 }, { unique: true });

export default mongoose.model("BattleResult", battleResultSchema);
