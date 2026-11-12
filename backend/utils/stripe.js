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

const call = async (method, path, body) => {
  const res = await fetch(`${API}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${process.env.STRIPE_SECRET_KEY}`,
      "Content-Type": "application/x-www-form-urlencoded",
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
