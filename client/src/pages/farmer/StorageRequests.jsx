import StorageConsentPage from '../../components/StorageConsentPage';

export default function StorageRequests() {
  return (
    <StorageConsentPage
      base="/farmer"
      title="Storage Requests"
      intro="Accepting a storage offer reserves the unit and starts transport. Storage begins after the driver delivers it."
      legNote={
        'This is pre-sale storage: your batch, in your own local warehouse, waiting for a buyer. ' +
        'A batch stays yours until it is awarded.'
      }
    />
  );
}
