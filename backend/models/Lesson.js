import mongoose from "mongoose";

/**
 * An Eco Academy lesson, editable from the admin dashboard. The built-in lessons
 * (utils/lessons.js) are copied in on first start; edits here then take over.
 * Arabic fields are optional; the app falls back to its own Arabic text.
 */
const lessonSchema = new mongoose.Schema(
  {
    lessonId: { type: String, required: true, unique: true, trim: true },
    emoji: { type: String, default: "🌱" },
    title: { type: String, required: true, trim: true, maxlength: 120 },
    titleAr: { type: String, default: "", trim: true, maxlength: 120 },
    cards: [{ type: String, maxlength: 400 }],
    cardsAr: [{ type: String, maxlength: 400 }],
    quiz: [
      {
        q: { type: String, required: true, maxlength: 200 },
        qAr: { type: String, default: "", maxlength: 200 },
        options: [{ type: String, maxlength: 100 }],
        optionsAr: [{ type: String, maxlength: 100 }],
        answer: { type: Number, min: 0, max: 2, required: true },
        why: { type: String, default: "", maxlength: 300 },
        whyAr: { type: String, default: "", maxlength: 300 },
        _id: false,
      },
    ],
    order: { type: Number, default: 0 },
    isActive: { type: Boolean, default: true },
  },
  { timestamps: true }
);

export default mongoose.model("Lesson", lessonSchema);
