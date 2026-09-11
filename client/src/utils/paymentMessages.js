export const paymentMessages = {
  cancelled: 'Checkout was cancelled. Check your payment history before starting another payment.',
  declined: 'The gateway reported a declined payment. Check your payment history before retrying.',
  'amount-mismatch': 'The gateway amount did not match our record. Payment is unconfirmed; contact support with the transaction reference.',
  'transaction-mismatch': 'The gateway returned a different transaction. Payment is unconfirmed; contact support with the transaction reference.',
  'currency-mismatch': 'The gateway currency did not match BDT. Payment is unconfirmed; contact support with the transaction reference.',
  'not-validated': 'Payment could not be confirmed yet. Check the gateway and your payment history before paying again.',
  error: 'Payment confirmation failed. This does not mean you were not charged. Check your payment history before retrying.',
  expired: 'This checkout is no longer pending. Check your payment history before starting another payment.',
};
