import { useCallback, useEffect, useState } from 'react';
import { Link, useParams } from 'react-router';
import { api } from '../../api/client';
import { date, dateTime, number, taka } from '../../utils/format';

export default function BatchDetail() {
  const { batchId } = useParams();
  const [batch, setBatch] = useState(null);
  const [bids, setBids] = useState([]);
  const [error, setError] = useState('');
  const [result, setResult] = useState(null);
  const [notice, setNotice] = useState('');
  const [schedule, setSchedule] = useState({ biddingStartTime: '', biddingEndTime: '' });

  const [awarding, setAwarding] = useState(null);
  const [terms, setTerms] = useState('ON_DELIVERY');
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    try {
      const [b, bd] = await Promise.all([
        api(`/farmer/batches/${batchId}`),
        api(`/farmer/batches/${batchId}/bids`),
      ]);
      setBatch(b);
      setBids(bd);
    } catch (e) {
      setError(e.message);
    }
  }, [batchId]);

  useEffect(() => {
    load();
  }, [load]);

  async function award(bidId) {
    setError('');
    setBusy(true);
    try {
      const res = await api(`/farmer/bids/${bidId}/award`, {
        method: 'POST',
        body: { paymentTerms: terms },
      });
      setResult(res);
      setAwarding(null);
      await load();
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }

  async function scheduleBidding(event) {
    event.preventDefault();
    setError('');
    setNotice('');
    setBusy(true);
    try {
      const updated = await api(`/farmer/batches/${batchId}/listing`, {
        method: 'PATCH',
        body: schedule,
      });
      setNotice(
        `Batch listed. Bidding opens ${dateTime(updated.biddingStartTime)} and closes ${dateTime(updated.biddingEndTime)}.`
      );
      await load();
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }

  if (error && !batch) return <p className="error">{error}</p>;
  if (!batch) return <p className="muted">Loading…</p>;

  const sold = ['SOLD', 'DELIVERED'].includes(batch.status);

  return (
    <div className="page">
      <p className="muted">
        <Link to="/farmer/batches">← My Batches</Link>
      </p>

      <div className="row">
        <div>
          <h1>
            Batch #{batch.batchId} — {batch.cropName}
          </h1>
          <p className="muted">
            {batch.farmName} · {batch.aratName} · harvested {date(batch.harvestDate)}
          </p>
        </div>
        <div>
          <span className={`tag tag-${batch.status.toLowerCase()}`}>
            {batch.status.replace(/_/g, ' ')}
          </span>
          {}
          {batch.soldQuantity > 0 && batch.status !== 'SOLD' && (
            <div className="muted small">
              Partially sold — {number(batch.availableQuantity)} kg still open
            </div>
          )}
        </div>
      </div>

      {result && (
        <div className="success">
          <strong>Sold.</strong> Sale order #{result.saleOrderId} created for{' '}
          {number(result.acceptedQuantity)} kg at {result.acceptedPricePerKg}/kg ={' '}
          {taka(result.totalAmount)}, terms {result.paymentTerms}. Transport request #
          {result.transportId} raised
          {result.bidsOutbid > 0 && `, ${result.bidsOutbid} rival bid(s) marked OUTBID`}.
        </div>
      )}

      {notice && <div className="success">{notice}</div>}

      <div className="stats">
        <Stat label="Total" value={`${number(batch.totalQuantity)} kg`} />
        <Stat label="Sold" value={`${number(batch.soldQuantity)} kg`} />
        {}
        <Stat label="Available" value={`${number(batch.availableQuantity)} kg`} />
        <Stat label="Minimum price" value={`${batch.minimumPrice}/kg`} />
        <Stat label="Highest bid" value={batch.currentHighestBid ?? '—'} />
        <Stat label="Bids" value={number(batch.bidCount)} />
        <Stat label="Bidders" value={number(batch.bidderCount)} />
        <Stat label="Bidding" value={batch.biddingState} />
      </div>

      <p className="muted">
        Crop base price ৳{batch.cropBasePrice}/{batch.unit}
        {batch.farmVerificationStatus === 'VERIFIED' && ' · ✓ Ministry verified farm'}
        {batch.pctAboveMinimum != null && ` · highest bid is ${batch.pctAboveMinimum}% above your minimum`}
        {batch.biddingStartTime && ` · opens ${dateTime(batch.biddingStartTime)}`}
        {batch.biddingEndTime && ` · closes ${dateTime(batch.biddingEndTime)}`}
      </p>

      {batch.status === 'CREATED' && (
        <section className="boxed">
          <h2>Complete draft and schedule bidding</h2>
          <p className="muted">
            This batch is saved as a draft and is not visible in the buyer marketplace. Set both
            dates to list it. Its minimum price is ৳{batch.minimumPrice}/kg; the crop base price is
            ৳{batch.cropBasePrice}/{batch.unit}.
          </p>
          <form onSubmit={scheduleBidding}>
            <div className="grid">
              <label>
                Bidding opens *
                <input
                  type="datetime-local"
                  value={schedule.biddingStartTime}
                  onChange={(e) =>
                    setSchedule({ ...schedule, biddingStartTime: e.target.value })
                  }
                  required
                />
              </label>
              <label>
                Bidding closes *
                <input
                  type="datetime-local"
                  value={schedule.biddingEndTime}
                  onChange={(e) =>
                    setSchedule({ ...schedule, biddingEndTime: e.target.value })
                  }
                  required
                />
              </label>
            </div>
            <button
              type="submit"
              disabled={
                busy ||
                !schedule.biddingStartTime ||
                !schedule.biddingEndTime ||
                new Date(schedule.biddingEndTime) <= new Date(schedule.biddingStartTime)
              }
            >
              {busy ? 'Listing…' : 'List batch for bidding'}
            </button>
          </form>
        </section>
      )}

      <h2>Bids</h2>
      {error && <p className="error">{error}</p>}

      {bids.length === 0 ? (
        <p className="muted">No bids yet.</p>
      ) : (
        <table>
          <thead>
            <tr>
              <th>Bid</th>
              <th>Buyer</th>
              <th>Type</th>
              <th className="num">Price/kg</th>
              <th className="num">Quantity</th>
              <th className="num">Value</th>
              <th>Placed</th>
              <th>Status</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {bids.map((b) => (
              <tr key={b.bidId} className={b.status === 'WON' ? 'row-won' : undefined}>
                <td>#{b.bidId}</td>
                <td>
                  {b.buyerName}
                  {b.businessName && <div className="muted small">{b.businessName}</div>}
                </td>
                <td>{b.buyerType || '—'}</td>
                <td className="num">
                  <strong>{b.bidPricePerKg}</strong>
                </td>
                <td className="num">{number(b.requestedQuantity)}</td>
                <td className="num">{taka(b.bidValue)}</td>
                <td>{dateTime(b.bidTime)}</td>
                <td>
                  <span className={`tag tag-${b.status.toLowerCase()}`}>{b.status}</span>
                </td>
                <td>
                  {b.status === 'ACTIVE' && !sold && (
                    <button type="button" className="small" onClick={() => setAwarding(b)}>
                      Accept
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      {}
      {awarding && (
        <div className="boxed confirm">
          <h3>Accept bid #{awarding.bidId}?</h3>
          <p>
            {awarding.buyerName} pays <strong>{awarding.bidPricePerKg}/kg</strong> for{' '}
            <strong>{number(awarding.requestedQuantity)} kg</strong> ={' '}
            <strong>{taka(awarding.bidValue)}</strong>.
          </p>
          <p className="muted">
            This marks the bid WON, closes the batch, creates the sale order and raises a transport
            request — all at once, or not at all.
          </p>

          <label>
            Payment terms
            <select value={terms} onChange={(e) => setTerms(e.target.value)}>
              <option value="ON_DELIVERY">On delivery — buyer pays once delivered</option>
              <option value="ADVANCE">Advance — buyer may pay before delivery</option>
            </select>
          </label>
          <p className="note">
            On-delivery terms mean payment is only accepted once the goods have been
            delivered.
          </p>

          <div className="actions">
            <button type="button" disabled={busy} onClick={() => award(awarding.bidId)}>
              {busy ? 'Awarding…' : 'Confirm and sell'}
            </button>
            <button type="button" className="ghost" onClick={() => setAwarding(null)}>
              Cancel
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

function Stat({ label, value }) {
  return (
    <div className="stat">
      <span className="stat-label">{label}</span>
      <span className="stat-value">{value}</span>
    </div>
  );
}
