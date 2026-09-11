# KrishiChain Client

React + Vite front end for all five KrishiChain roles. The application has 29
page components, role-aware navigation, loading/empty/error states, and forms
for the six main database workflows.

## Setup

```bash
cd client
npm install
npm run dev       # http://localhost:5173
npm run build
npm run lint
```

The API must also be running on `http://localhost:5000`. Vite proxies `/api`
to that server during development.

## Pages by role

| Access | Pages |
|---|---|
| Public | Login, registration |
| Signed in | Profile and role-home redirect |
| Farmer | Dashboard, farms, batches, batch creation/detail, orders, payments, storage requests |
| Buyer | Dashboard, listings, batch detail, bids, orders, payments, storage, reviews |
| Storage manager | Dashboard, warehouses/units, requests and allocations |
| Transport personnel | Assignment dashboard, pickup and delivery actions |
| Admin | Dashboard, users, prices, complaints, farm verification and PL/SQL-backed reports |

`ProtectedRoute` improves navigation but is not the security boundary; the API
authenticates and authorizes every protected request.

## Layout

```text
src/
  api/client.js            fetch wrapper and bearer-token handling
  context/AuthContext.jsx  session state and auth actions
  components/              role navigation and protected routing
  pages/                   public pages plus five role modules
```

All seeded accounts use `Demo@1234`. The registration form is role-driven:
`ROLE_FIELDS` in `RegisterPage.jsx` must stay aligned with `SUBCLASS` in
`server/src/services/auth.service.js`. Phone numbers remain a multivalued
attribute and are submitted with the user in one registration transaction.

Import router APIs from `react-router`; this project uses React Router 8.

Browser regression checks run from `server/` with `npm run test:browser` after
`npm run build` here. They use the built client, a temporary API port and rolled-back
Oracle records; they do not operate on an existing user's account. See `../docs/TESTING.md`.
