export const sendServerError = (res, fallback = "Something went wrong") => {
  return res.status(500).json({
    success: false,
    message: fallback,
  });
};
