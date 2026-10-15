// Money is always an integer amount of minor units (cents, öre, ...).
export type CurrencyCode = string; // ISO 4217, e.g. "EUR", "NOK"

export interface Money {
  amountMinor: number; // integer, never a float
  currency: CurrencyCode;
}

export function money(amountMinor: number, currency: CurrencyCode): Money {
  if (!Number.isInteger(amountMinor)) {
    throw new Error("amountMinor must be an integer number of minor units");
  }
  if (!/^[A-Z]{3}$/.test(currency)) {
    throw new Error("currency must be an ISO 4217 alphabetic code");
  }
  return { amountMinor, currency };
}
