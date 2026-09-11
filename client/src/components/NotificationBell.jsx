import { useCallback, useEffect, useRef, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { api } from '../api/client';

export default function NotificationBell() {
  const { user } = useAuth();
  const [open, setOpen] = useState(false);
  const [items, setItems] = useState([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const wrapRef = useRef(null);
  const buttonRef = useRef(null);

  const load = useCallback(async () => {
    if (!user) return;
    setLoading(true);
    setError('');
    try {
      const data = await api('/notifications');
      setItems(data.notifications || []);
      setUnreadCount(Number(data.unreadCount || 0));
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }, [user]);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    if (!open) return undefined;
    const onDown = (e) => {
      if (wrapRef.current && !wrapRef.current.contains(e.target)) setOpen(false);
    };
    const onKey = (e) => {
      if (e.key === 'Escape') {
        setOpen(false);
        buttonRef.current?.focus();
      }
    };
    document.addEventListener('mousedown', onDown);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onDown);
      document.removeEventListener('keydown', onKey);
    };
  }, [open]);

  if (!user) return null;

  const toggle = () => {
    const next = !open;
    setOpen(next);
    if (next) load();
  };

  const markRead = async (item) => {
    if (item.isRead === 'Y') return;
    try {
      await api(`/notifications/${item.notificationId}/read`, { method: 'POST' });
      setItems((current) =>
        current.map((entry) =>
          entry.notificationId === item.notificationId ? { ...entry, isRead: 'Y' } : entry
        )
      );
      setUnreadCount((count) => Math.max(0, count - 1));
    } catch (e) {
      setError(e.message);
    }
  };

  return (
    <div className="notif" ref={wrapRef}>
      <button
        type="button"
        ref={buttonRef}
        className="notif-button"
        aria-haspopup="true"
        aria-expanded={open}
        aria-label="Notifications"
        onClick={toggle}
      >
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.6"
          strokeLinecap="round"
          strokeLinejoin="round"
          aria-hidden="true"
        >
          <path d="M18 8.5a6 6 0 1 0-12 0c0 5-2 6.5-2 6.5h16s-2-1.5-2-6.5Z" />
          <path d="M10.5 18.5a1.9 1.9 0 0 0 3 0" />
        </svg>
        {unreadCount > 0 && (
          <span className="notif-badge" aria-label={`${unreadCount} unread`}>
            {unreadCount > 9 ? '9+' : unreadCount}
          </span>
        )}
      </button>

      {open && (
        <div className="notif-panel" role="dialog" aria-label="Notifications">
          <div className="notif-header">
            <strong>Notifications</strong>
            <span className="muted">{unreadCount} unread</span>
          </div>
          {loading && !items.length && <p className="notif-empty muted">Loading…</p>}
          {error && <p className="notif-empty error">{error}</p>}
          {!loading && !error && !items.length && (
            <p className="notif-empty muted">No notifications yet.</p>
          )}
          {items.length > 0 && (
            <ul className="notif-list">
              {items.map((item) => (
                <li key={item.notificationId}>
                  <button
                    type="button"
                    className={`notif-item ${item.isRead === 'N' ? 'unread' : ''}`}
                    onClick={() => markRead(item)}
                  >
                    <span className="notif-item-title">{item.title}</span>
                    <span className="notif-item-message">{item.message}</span>
                    <time dateTime={item.createdAt}>
                      {new Date(item.createdAt).toLocaleString()}
                    </time>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}
    </div>
  );
}
