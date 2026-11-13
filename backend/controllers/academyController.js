import LessonProgress from "../models/LessonProgress.js";
import { creditPoints } from "../utils/ledger.js";
import { calendarDayStamp } from "../utils/verifiedProgress.js";
import { sendServerError } from "../utils/httpError.js";
import { LESSONS, LESSON_POINTS, currentStreak, lessonById, lessonForDay, markQuiz, publicLesson } from "../utils/lessons.js";

// GET /api/academy — today's lesson, the library and my streak.
export const academyHome = async (req, res) => {
  try {
    const today = calendarDayStamp(new Date());
    const progress = await LessonProgress.find({ user: req.user._id }).lean();
    const done = new Map(progress.map((p) => [p.lessonId, p]));
    const passedDays = progress.filter((p) => p.passed).map((p) => p.day);
    const todays = lessonForDay(today);
    res.json({
      success: true,
      today: { ...publicLesson(todays), passed: done.get(todays.id)?.passed === true },
      streak: currentStreak(passedDays, today),
      passed: progress.filter((p) => p.passed).length,
      total: LESSONS.length,
      points: LESSON_POINTS,
      library: LESSONS.map((l) => ({ id: l.id, emoji: l.emoji, title: l.title, passed: done.get(l.id)?.passed === true, score: done.get(l.id)?.score ?? null })),
    });
  } catch (error) {
    return sendServerError(res, "Unable to load Eco Academy");
  }
};

// GET /api/academy/:id
export const lessonDetail = (req, res) => {
  const l = lessonById(req.params.id);
  if (!l) return res.status(404).json({ success: false, message: "Lesson not found" });
  res.json({ success: true, lesson: publicLesson(l) });
};

// POST /api/academy/:id/answers { answers: [i, i, i] } — points the first time a lesson is passed.
export const submitAnswers = async (req, res) => {
  try {
    const l = lessonById(req.params.id);
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
