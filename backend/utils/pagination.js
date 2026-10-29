export const parsePagination = (
  query = {},
  { defaultLimit = 20, maxLimit = 50 } = {}
) => {
  const pageRaw = Number.parseInt(String(query.page ?? "1"), 10);
  const limitRaw = Number.parseInt(String(query.limit ?? String(defaultLimit)), 10);
  const page = Number.isFinite(pageRaw) && pageRaw > 0 ? pageRaw : 1;
  const unbounded = Number.isFinite(limitRaw) && limitRaw > 0 ? limitRaw : defaultLimit;
  const limit = Math.min(maxLimit, unbounded);
  const skip = (page - 1) * limit;
  return { page, limit, skip };
};
