import { useCallback, useEffect, useState } from 'react';
import { api } from '../../api/client';
import { date, number } from '../../utils/format';

const STATUSES = ['PENDING', 'VERIFIED', 'REJECTED'];

export default function FarmVerifications() {
  const [status, setStatus] = useState('PENDING');
  const [farms, setFarms] = useState(null);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [busy, setBusy] = useState(null);

  const load = useCallback(async () => {
    try {
      setFarms(await api(`/admin/farm-verifications?status=${status}`));
    } catch (e) {
      setError(e.message);
    }
  }, [status]);

  useEffect(() => {
    load();
  }, [load]);

  async function review(farmId, decision) {
    setBusy(farmId);
    setError('');
    setNotice('');
    try {
      await api(`/admin/farm-verifications/${farmId}`, {
        method: 'PATCH',
        body: { decision },
      });
      setNotice(`Farm #${farmId} is now ${decision.toLowerCase()}.`);
      await load();
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(null);
    }
  }

  return (
    <div className="page">
      <h1>Farm Verification</h1>
      <p className="muted">
        Ministry review queue, oldest request first. Pending verification does not stop a farmer
        from using the marketplace.
      </p>

      <label className="filters">
        Status
        <select value={status} onChange={(e) => setStatus(e.target.value)}>
          {STATUSES.map((value) => <option key={value}>{value}</option>)}
        </select>
      </label>

      {error && <p className="error">{error}</p>}
      {notice && <p className="success">{notice}</p>}
      {!farms ? (
        <p className="muted">Loading…</p>
      ) : farms.length === 0 ? (
        <p className="muted">No farms in this queue.</p>
      ) : (
        <table>
          <thead>
            <tr>
              <th>Farm</th><th>Farmer</th><th>NID</th><th>Location</th>
              <th className="num">Area</th><th className="num">Batches</th>
              <th>Requested</th><th>Reviewed</th><th />
            </tr>
          </thead>
          <tbody>
            {farms.map((farm) => (
              <tr key={farm.farmId}>
                <td>#{farm.farmId} · {farm.farmName}</td>
                <td>{farm.farmerName}<br /><span className="muted small">{farm.farmerEmail}</span></td>
                <td>{farm.nid}</td>
                <td>{[farm.location, farm.district].filter(Boolean).join(', ')}</td>
                <td className="num">{number(farm.area)} acres</td>
                <td className="num">{number(farm.batchCount)}</td>
                <td>{date(farm.verificationRequestedAt)}</td>
                <td>{date(farm.verificationReviewedAt)}{farm.reviewedBy ? ` · ${farm.reviewedBy}` : ''}</td>
                <td>
                  {status === 'PENDING' && (
                    <div className="actions">
                      <button type="button" className="small" disabled={busy === farm.farmId}
                        onClick={() => review(farm.farmId, 'VERIFIED')}>Verify</button>
                      <button type="button" className="small ghost" disabled={busy === farm.farmId}
                        onClick={() => review(farm.farmId, 'REJECTED')}>Reject</button>
                    </div>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
