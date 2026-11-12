/** Use after `protect`. Lets only admin accounts through. */
export const isAdminUser = (user) => user?.role === "admin" && user?.isSuspended !== true;

const requireAdmin = (req, res, next) => {
  if (!isAdminUser(req.user)) {
    return res.status(403).json({
      success: false,
      message: "Admin access required",
    });
  }
  next();
};

export default requireAdmin;
