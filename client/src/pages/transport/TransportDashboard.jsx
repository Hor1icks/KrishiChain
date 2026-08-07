import { useCallback, useEffect, useState } from 'react';
import { api } from '../../api/client';
import { date, number } from '../../utils/format';

export default function TransportDashboard() {
  const [data, setData] = useState(null);
  const [error, setError] = useState('');
  const load = useCallback(() => api('/transport/dashboard').then(setData).catch((e) => setError(e.message)), []);
  useEffect(() => { load(); }, [load]);
  async function update(id, status) {
    setError('');
    try { await api(`/transport/assignments/${id}/status`, { method: 'PATCH', body: { status } }); await load(); }
    catch (e) { setError(e.message); }
  }
  if (!data && !error) return <p className="muted">Loading...</p>;
  return <div className="page">
    <div className="page-heading"><div><h1>My deliveries</h1><p className="muted">Assigned vehicles, routes and delivery progress</p></div></div>
    {error && <p className="error" role="alert">{error}</p>}
    {!data?.assignments?.length ? <div className="empty-state"><h2>No assignments</h2><p className="muted">New assignments will appear here.</p></div> :
      <div className="card-grid">{data.assignments.map((a) => <article className="card" key={a.ASSIGNMENTID}>
        <div className="row"><strong>Order #{a.SALEORDERID}</strong><span className="tag">{a.DELIVERYSTATUS}</span></div>
        <p>{a.PICKUPLOCATION || 'Pickup TBD'} → {a.DELIVERYLOCATION || 'Delivery TBD'}</p>
        <p className="muted">{a.VEHICLENO} · {a.VEHICLETYPE || 'Vehicle'} · {number(a.ACCEPTEDQUANTITY)} kg · assigned {date(a.ASSIGNEDDATE)}</p>
        {a.ASSIGNMENTSTATUS === 'ACTIVE' && <div className="actions">
          {['PICKED_UP','IN_TRANSIT','DELIVERED','FAILED'].map((s) => <button className="small" key={s} onClick={() => update(a.ASSIGNMENTID, s)}>{s.replace('_',' ')}</button>)}
        </div>}
      </article>)}</div>}
  </div>;
}
