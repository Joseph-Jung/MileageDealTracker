import Link from 'next/link'

export default function Home() {
  return (
    <div>
      <section className="mb-12">
        <h2 className="text-4xl font-bold mb-4">Welcome to Credit Card Deals Tracker</h2>
        <p className="text-xl text-gray-700 mb-6">
          Track the latest credit card welcome offers with transparent value scores.
          Never miss a great bonus again.
        </p>
        <div className="flex gap-4">
          <Link
            href="/offers"
            className="bg-blue-600 text-white px-6 py-3 rounded-lg font-semibold hover:bg-blue-700 transition"
          >
            View All Offers
          </Link>
          <Link
            href="/issuers"
            className="bg-gray-200 text-gray-800 px-6 py-3 rounded-lg font-semibold hover:bg-gray-300 transition"
          >
            Browse by Issuer
          </Link>
        </div>
      </section>

      <section className="grid md:grid-cols-3 gap-6 mb-12">
        <div className="bg-white p-6 rounded-lg shadow-md">
          <h3 className="text-xl font-bold mb-2">📊 Transparent Scoring</h3>
          <p className="text-gray-600">
            Our value scores use published cents-per-point valuations. No hidden algorithms.
          </p>
        </div>
        <div className="bg-white p-6 rounded-lg shadow-md">
          <h3 className="text-xl font-bold mb-2">📈 Track Changes</h3>
          <p className="text-gray-600">
            See historical bonus trends and get alerts when offers improve.
          </p>
        </div>
        <div className="bg-white p-6 rounded-lg shadow-md">
          <h3 className="text-xl font-bold mb-2">✉️ Email Alerts</h3>
          <p className="text-gray-600">
            Subscribe to weekly digests or instant alerts for cards you're watching.
          </p>
        </div>
      </section>

      <section className="bg-blue-50 p-8 rounded-lg">
        <h3 className="text-2xl font-bold mb-4">How Our Scoring Works</h3>
        <div className="grid md:grid-cols-2 gap-6">
          <div>
            <h4 className="font-semibold mb-2">Cents-per-Point Values</h4>
            <ul className="space-y-1 text-gray-700">
              <li>• AA (American Airlines): 1.4¢</li>
              <li>• United MileagePlus: 1.2¢</li>
              <li>• Delta SkyMiles: 1.1¢</li>
              <li>• Amex Membership Rewards: 1.7¢</li>
              <li>• Chase Ultimate Rewards: 1.6¢</li>
              <li>• Citi ThankYou Points: 1.5¢</li>
            </ul>
          </div>
          <div>
            <h4 className="font-semibold mb-2">Value Formula</h4>
            <div className="bg-white p-4 rounded border border-blue-200 font-mono text-sm">
              value = (bonus × cpp) + credits - annual_fee
            </div>
            <p className="text-gray-600 mt-2 text-sm">
              We factor in statement credits and waived first-year fees to show true value.
            </p>
          </div>
        </div>
      </section>
    </div>
  )
}
