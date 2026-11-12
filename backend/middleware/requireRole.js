/** Use after `protect`. Allows only the listed roles (admins always pass). */
const requireRole = (...roles) => (req, res, next) => {
  const role = req.user?.role;
  if (role === "admin" || roles.includes(role)) return next();
  return res.status(403).json({ success: false, message: "You do not have access to this area" });
};

export default requireRole;
