import LessonProgress from "../models/LessonProgress.js";
import { creditPoints } from "../utils/ledger.js";
import { calendarDayStamp } from "../utils/verifiedProgress.js";
import { sendServerError } from "../utils/httpError.js";
import Lesson from "../models/Lesson.js";
import { LESSONS, LESSON_POINTS, currentStreak, fromDoc, lessonById, lessonForDay, lessonProblem, markQuiz, publicLesson } from "../utils/lessons.js";

/** Active lessons from the database (admin-editable), or the built-in set before the first sync. */
const library = async () => {
  const docs = await Lesson.find({ isActive: true }).sort({ order: 1, createdAt: 1 }).lean();
  return docs.length ? docs.map(fromDoc) : LESSONS;
};

/** Copy the built-in lessons into the database once, without touching edited ones. */
export const syncLessons = async () => {
  for (const [i, l] of LESSONS.entries()) {
    await Lesson.updateOne(
      { lessonId: l.id },
      { $setOnInsert: { lessonId: l.id, emoji: l.emoji, title: l.title, cards: l.cards, quiz: l.quiz.map((q) => ({ q: q.q, options: q.options, answer: q.answer, why: q.why })), order: i * 10 } },
      { upsert: true }
    );
  }
};

// GET /api/academy — today's lesson, the library and my streak.
export const academyHome = async (req, res) => {
  try {
    const today = calendarDayStamp(new Date());
    const progress = await LessonProgress.find({ user: req.user._id }).lean();
    const done = new Map(progress.map((p) => [p.lessonId, p]));
    const passedDays = progress.filter((p) => p.passed).map((p) => p.day);
    const lessons = await library();
    const todays = lessonForDay(today, lessons);
    res.json({
      success: true,
      today: { ...publicLesson(todays), passed: done.get(todays.id)?.passed === true },
      streak: currentStreak(passedDays, today),
      passed: progress.filter((p) => p.passed).length,
      total: lessons.length,
      points: LESSON_POINTS,
      library: lessons.map((l) => ({ id: l.id, emoji: l.emoji, title: l.title, ...(l.titleAr ? { titleAr: l.titleAr } : {}), passed: done.get(l.id)?.passed === true, score: done.get(l.id)?.score ?? null })),
    });
  } catch (error) {
    return sendServerError(res, "Unable to load Eco Academy");
  }
};

// GET /api/academy/:id
export const lessonDetail = async (req, res) => {
  try {
    const l = lessonById(req.params.id, await library());
    if (!l) return res.status(404).json({ success: false, message: "Lesson not found" });
    res.json({ success: true, lesson: publicLesson(l) });
  } catch (error) {
    return sendServerError(res, "Unable to load the lesson");
  }
};

// POST /api/academy/:id/answers { answers: [i, i, i] } — points the first time a lesson is passed.
export const submitAnswers = async (req, res) => {
  try {
    const l = lessonById(req.params.id, await library());
    if (!l) return res.status(404).json({ success: false, message: "Lesson not found" });
    const marked = markQuiz(l, Array.isArray(req.body?.answers) ? req.body.answers : []);
    const day = calendarDayStamp(new Date());

    let earned = 0;
    if (marked.passed) {
      // Only the first pass flips passed:false -> true, so points can't be paid twice.
      const before = await LessonProgress.findOneAndUpdate(
        { user: req.user._id, lessonId: l.id, passed: { $ne: true } },
        { $set: { passed: true, score: marked.score, day, points: LESSON_POINTS } },
        { upsert: true, new: false }
      ).catch((e) => (e?.code === 11000 ? "already" : Promise.reject(e)));
      if (before !== "already") {
        await creditPoints({ userId: req.user._id, amount: LESSON_POINTS, type: "academy", reason: `Eco Academy: ${l.title}` });
        earned = LESSON_POINTS;
      }
    } else {
      await LessonProgress.updateOne(
        { user: req.user._id, lessonId: l.id, passed: { $ne: true } },
        { $setOnInsert: { day }, $max: { score: marked.score } },
        { upsert: true }
      ).catch((e) => (e?.code === 11000 ? null : Promise.reject(e)));
    }
    res.json({ success: true, ...marked, earned });
  } catch (error) {
    return sendServerError(res, "Unable to check your answers");
  }
};

// ---------- admin ----------

// GET /api/admin/lessons — every lesson (active or not) with how many passed it.
export const adminLessons = async (req, res) => {
  try {
    const [docs, passes] = await Promise.all([
      Lesson.find().sort({ order: 1, createdAt: 1 }).lean(),
      LessonProgress.aggregate([{ $group: { _id: "$lessonId", attempts: { $sum: 1 }, passed: { $sum: { $cond: ["$passed", 1, 0] } } } }]),
    ]);
    const p = Object.fromEntries(passes.map((x) => [x._id, x]));
    res.json({ success: true, lessons: docs.map((d) => ({ ...d, attempts: p[d.lessonId]?.attempts || 0, passed: p[d.lessonId]?.passed || 0 })) });
  } catch (error) {
    return sendServerError(res, "Unable to load lessons");
  }
};

const lessonBody = (b) => ({
  emoji: String(b.emoji || "🌱").slice(0, 8),
  title: String(b.title || "").trim(),
  titleAr: String(b.titleAr || "").trim(),
  cards: (Array.isArray(b.cards) ? b.cards : []).map((c) => String(c).trim()).filter(Boolean).slice(0, 5),
  cardsAr: (Array.isArray(b.cardsAr) ? b.cardsAr : []).map((c) => String(c).trim()).slice(0, 5),
  quiz: (Array.isArray(b.quiz) ? b.quiz : []).slice(0, 5).map((q) => ({
    q: String(q.q || "").trim(),
    qAr: String(q.qAr || "").trim(),
    options: (Array.isArray(q.options) ? q.options : []).map((o) => String(o).trim()),
    optionsAr: (Array.isArray(q.optionsAr) ? q.optionsAr : []).map((o) => String(o).trim()),
    answer: Number(q.answer),
    why: String(q.why || "").trim(),
    whyAr: String(q.whyAr || "").trim(),
  })),
  ...(b.order !== undefined ? { order: Number(b.order) || 0 } : {}),
  ...(b.isActive !== undefined ? { isActive: Boolean(b.isActive) } : {}),
});

// POST /api/admin/lessons
export const adminCreateLesson = async (req, res) => {
  try {
    const body = lessonBody(req.body || {});
    const problem = lessonProblem(body);
    if (problem) return res.status(400).json({ success: false, message: problem });
    const slug = body.title.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 40) || "lesson";
    const lessonId = (await Lesson.exists({ lessonId: slug })) ? `${slug}-${Date.now().toString(36)}` : slug;
    res.status(201).json({ success: true, lesson: await Lesson.create({ ...body, lessonId, order: body.order ?? 1000 }) });
  } catch (error) {
    return sendServerError(res, "Unable to add the lesson");
  }
};

// PATCH /api/admin/lessons/:id
export const adminUpdateLesson = async (req, res) => {
  try {
    const body = lessonBody(req.body || {});
    if (req.body?.title !== undefined || req.body?.quiz !== undefined) {
      const problem = lessonProblem(body);
      if (problem) return res.status(400).json({ success: false, message: problem });
    }
    const set = req.body?.title !== undefined || req.body?.quiz !== undefined ? body : { ...(body.isActive !== undefined ? { isActive: body.isActive } : {}), ...(body.order !== undefined ? { order: body.order } : {}) };
    const l = await Lesson.findByIdAndUpdate(req.params.id, { $set: set }, { new: true });
    if (!l) return res.status(404).json({ success: false, message: "Lesson not found" });
    res.json({ success: true, lesson: l });
  } catch (error) {
    return sendServerError(res, "Unable to update the lesson");
  }
};
