const MIN_PROD_SECRET_LENGTH = 32;

export const isProduction = () => process.env.NODE_ENV === "production";

export const getJwtSecret = () => process.env.JWT_SECRET;

export const assertJwtSecret = () => {
  const secret = getJwtSecret();

  if (!secret || !String(secret).trim()) {
    console.error("JWT_SECRET is required. Refusing to start.");
    process.exit(1);
  }

  if (isProduction() && String(secret).length < MIN_PROD_SECRET_LENGTH) {
    console.error(
      `JWT_SECRET is too short for production (need at least ${MIN_PROD_SECRET_LENGTH} characters). Refusing to start. Set a strong secret without rotating an existing production value from this process.`
    );
    process.exit(1);
  }
};
