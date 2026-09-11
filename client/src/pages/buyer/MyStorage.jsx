import StorageConsentPage from '../../components/StorageConsentPage';

export default function MyStorage() {
  return (
    <StorageConsentPage
      base="/buyer"
      title="My Storage"
      intro="Once you buy a batch, a manager can reserve a unit. It stays in transit until a driver delivers it there."
      legNote={
        'This is post-sale storage against one of your orders. Rejecting a proposal simply leaves ' +
        'the order open for a different manager to offer against.'
      }
    />
  );
}
