/** Light in-process jobs (Render keeps one instance running). */
export const startScheduler = () => {
  const run = async () => {
    try {
      // Streak reminders at 19:00–21:59 UAE time.
      const uaeHour = (new Date().getUTCHours() + 4) % 24;
      if (uaeHour >= 19 && uaeHour < 22) {
        const { sendStreakReminders } = await import("../controllers/growthController.js");
        const n = await sendStreakReminders();
        if (n) console.log(`Streak reminders sent: ${n}`);
      }
      // Partner reports on the 1st of the month, from 09:00 UAE time.
      const uaeNow = new Date(Date.now() + 4 * 3600e3);
      if (uaeNow.getUTCDate() === 1 && uaeHour >= 9) {
        const { sendMonthlyPartnerReports } = await import("../controllers/partnerController.js");
        const sent = await sendMonthlyPartnerReports();
        if (sent) console.log(`Partner reports emailed: ${sent}`);
      }
    } catch (e) {
      console.error("Scheduler error:", e.message);
    }
  };
  setTimeout(run, 60 * 1000);
  return setInterval(run, 20 * 60 * 1000);
};
