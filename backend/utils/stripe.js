/**
 * Minimal Stripe Checkout client (no SDK). Enabled when STRIPE_SECRET_KEY is set.
 * Amounts are in AED; Stripe expects the smallest unit (fils).
 */
const API = "https://api.stripe.com/v1";

export const paymentsEnabled = () => /^sk_(test|live)_/.test(process.env.STRIPE_SECRET_KEY || "");

export const toFils = (aed) => Math.round((Number(aed) || 0) * 100);

/** Flatten nested params into Stripe's form encoding (a[b][0][c]=v). */
export const formEncode = (obj, prefix = "", out = new URLSearchParams()) => {
  for (const [k, v] of Object.entries(obj)) {
    if (v === undefined || v === null) continue;
    const key = prefix ? `${prefix}[${k}]` : k;
    if (typeof v === "object") formEncode(v, key, out);
    else out.append(key, String(v));
  }
  return out;
};

const call = async (method, path, body, extraHeaders = {}) => {
  const res = await fetch(`${API}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${process.env.STRIPE_SECRET_KEY}`,
      "Content-Type": "application/x-www-form-urlencoded",
      ...extraHeaders,
    },
    body: body ? formEncode(body) : undefined,
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data?.error?.message || `Stripe error ${res.status}`);
  return data;
};

export const createCheckoutSession = ({ title, amountAed, successUrl, cancelUrl, metadata, email }) =>
  call("POST", "/checkout/sessions", {
    mode: "payment",
    success_url: successUrl,
    cancel_url: cancelUrl,
    customer_email: email || undefined,
    line_items: [
      { quantity: 1, price_data: { currency: "aed", unit_amount: toFils(amountAed), product_data: { name: String(title).slice(0, 120) } } },
    ],
    metadata,
  });

export const getCheckoutSession = (id) => call("GET", `/checkout/sessions/${encodeURIComponent(id)}`);

// ---------- Stripe Connect: paying creators for brand deals ----------

/** An Express connected account for a creator (they add bank details on Stripe's own pages). */
export const createConnectAccount = ({ email, country = process.env.STRIPE_CONNECT_COUNTRY || "AE" }) =>
  call("POST", "/accounts", { type: "express", country, email, capabilities: { transfers: { requested: true } } });

/** A one-time Stripe page where the creator adds their bank details. */
export const createAccountLink = ({ account, refreshUrl, returnUrl }) =>
  call("POST", "/account_links", { account, refresh_url: refreshUrl, return_url: returnUrl, type: "account_onboarding" });

export const getAccount = (id) => call("GET", `/accounts/${encodeURIComponent(id)}`);

/** Send the creator's share. The idempotency key makes a double click pay only once. */
export const createTransfer = ({ amountAed, destination, metadata, idempotencyKey }) =>
  call("POST", "/transfers", { amount: toFils(amountAed), currency: "aed", destination, metadata }, idempotencyKey ? { "Idempotency-Key": idempotencyKey } : {});
