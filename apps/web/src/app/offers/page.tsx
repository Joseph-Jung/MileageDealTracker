async function getOffers() {
  const baseUrl = process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000';
  const res = await fetch(`${baseUrl}/api/offers`, {
    cache: 'no-store',
  });

  if (!res.ok) {
    throw new Error('Failed to fetch offers');
  }

  return res.json();
}

export default async function OffersPage() {
  let data;

  try {
    data = await getOffers();
  } catch (error) {
    return (
      <div className="bg-yellow-50 border border-yellow-200 p-6 rounded-lg">
        <h2 className="text-xl font-bold mb-2">Database Not Connected</h2>
        <p className="text-gray-700 mb-4">
          To see offers, you need to set up the database:
        </p>
        <ol className="list-decimal list-inside space-y-2 text-gray-700 mb-4">
          <li>Install PostgreSQL or use a hosted service</li>
          <li>Copy .env.example to .env</li>
          <li>Update DATABASE_URL in .env</li>
          <li>Run: cd packages/database && pnpm db:generate && pnpm db:push && pnpm db:seed</li>
        </ol>
        <p className="text-sm text-gray-600">
          See README.md for detailed setup instructions.
        </p>
      </div>
    );
  }

  const { data: offers } = data;

  if (!offers || offers.length === 0) {
    return (
      <div className="bg-blue-50 border border-blue-200 p-6 rounded-lg">
        <h2 className="text-xl font-bold mb-2">No Offers Found</h2>
        <p className="text-gray-700">
          Run the seed script to populate the database with sample offers:
        </p>
        <code className="block bg-white p-2 mt-2 rounded text-sm">
          cd packages/database && pnpm db:seed
        </code>
      </div>
    );
  }

  return (
    <div>
      <h1 className="text-3xl font-bold mb-6">Current Credit Card Offers</h1>
      <p className="text-gray-600 mb-8">
        Showing {offers.length} active offers, sorted by estimated value
      </p>

      <div className="space-y-4">
        {offers.map((offer: any) => (
          <div key={offer.id} className="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition">
            <div className="flex justify-between items-start mb-4">
              <div>
                <h3 className="text-xl font-bold text-gray-900">
                  {offer.product.issuer.name} {offer.product.name}
                </h3>
                <p className="text-blue-600 font-semibold">{offer.headline}</p>
              </div>
              <div className="text-right">
                <div className="text-2xl font-bold text-green-600">
                  ${offer.calculatedValue.netValue}
                </div>
                <div className="text-sm text-gray-500">Est. Value</div>
              </div>
            </div>

            <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-4">
              <div>
                <div className="text-sm text-gray-500">Bonus</div>
                <div className="font-semibold">
                  {offer.bonusPoints.toLocaleString()} {offer.product.currency}
                </div>
              </div>
              <div>
                <div className="text-sm text-gray-500">Min Spend</div>
                <div className="font-semibold">
                  ${offer.minSpendAmount.toLocaleString()} / {offer.minSpendWindowDays}d
                </div>
              </div>
              <div>
                <div className="text-sm text-gray-500">Annual Fee</div>
                <div className="font-semibold">
                  ${offer.annualFee}
                  {offer.firstYearWaived && (
                    <span className="text-green-600 text-xs ml-1">(Waived 1st yr)</span>
                  )}
                </div>
              </div>
              <div>
                <div className="text-sm text-gray-500">Points Value</div>
                <div className="font-semibold">
                  {offer.calculatedValue.centsPerPoint}¢ each
                </div>
              </div>
            </div>

            <div className="flex gap-4 items-center">
              <a
                href={offer.landingUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="bg-blue-600 text-white px-4 py-2 rounded font-semibold hover:bg-blue-700 transition"
              >
                Apply Now
              </a>
              <span className="text-sm text-gray-500">
                Last verified: {new Date(offer.lastVerifiedAt).toLocaleDateString()}
              </span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
