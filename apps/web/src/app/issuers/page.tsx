import { IssuerRepository } from '../../../prisma-lib/repositories/issuer.repository';

const issuerRepo = new IssuerRepository();

export default async function IssuersPage() {
  let issuers;

  try {
    issuers = await issuerRepo.findAll();
  } catch (error) {
    return (
      <div className="bg-yellow-50 border border-yellow-200 p-6 rounded-lg">
        <h2 className="text-xl font-bold mb-2">Database Not Connected</h2>
        <p className="text-gray-700">
          Please set up the database to view issuers. See the offers page for instructions.
        </p>
      </div>
    );
  }

  return (
    <div>
      <h1 className="text-3xl font-bold mb-6">Credit Card Issuers</h1>
      <p className="text-gray-600 mb-8">Browse offers by issuer</p>

      <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
        {issuers.map((issuer) => (
          <div key={issuer.id} className="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition">
            <h3 className="text-xl font-bold mb-2">{issuer.name}</h3>
            <p className="text-gray-600 mb-4">
              {issuer._count.products} card products
            </p>
            <a
              href={issuer.website}
              target="_blank"
              rel="noopener noreferrer"
              className="text-blue-600 hover:underline text-sm"
            >
              Visit website →
            </a>
          </div>
        ))}
      </div>
    </div>
  );
}
