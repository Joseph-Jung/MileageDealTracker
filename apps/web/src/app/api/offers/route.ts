import { NextResponse } from 'next/server';
import { OfferRepository } from '../../../../prisma-lib/repositories/offer.repository';
import { CurrencyValuationRepository } from '../../../../prisma-lib/repositories/currency-valuation.repository';

const offerRepo = new OfferRepository();
const currencyRepo = new CurrencyValuationRepository();

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);

    const filters = {
      issuerSlug: searchParams.get('issuer') || undefined,
      currencyCode: searchParams.get('currency') || undefined,
      minBonus: searchParams.get('minBonus') ? parseInt(searchParams.get('minBonus')!) : undefined,
    };

    const offers = await offerRepo.findActive(filters);
    const valuations = await currencyRepo.getBulkValuations();

    // Calculate values for each offer
    const offersWithValues = offers.map(offer => {
      const cpp = valuations[offer.product.currencyCode] || 1.0;
      const bonusValue = (offer.bonusPoints * cpp) / 100;
      const effectiveAF = offer.firstYearWaived ? 0 : Number(offer.annualFee);
      const netValue = bonusValue + Number(offer.statementCredits) - effectiveAF;

      return {
        id: offer.id,
        headline: offer.headline,
        bonusPoints: offer.bonusPoints,
        minSpendAmount: Number(offer.minSpendAmount),
        minSpendWindowDays: offer.minSpendWindowDays,
        annualFee: Number(offer.annualFee),
        firstYearWaived: offer.firstYearWaived,
        statementCredits: Number(offer.statementCredits),
        landingUrl: offer.landingUrl,
        lastVerifiedAt: offer.lastVerifiedAt,
        product: {
          name: offer.product.name,
          slug: offer.product.slug,
          currency: offer.product.currency,
          currencyCode: offer.product.currencyCode,
          issuer: {
            name: offer.product.issuer.name,
            slug: offer.product.issuer.slug,
          },
        },
        calculatedValue: {
          bonusValue: Math.round(bonusValue),
          netValue: Math.round(netValue),
          centsPerPoint: cpp,
        },
      };
    });

    // Sort by net value descending
    offersWithValues.sort((a, b) => b.calculatedValue.netValue - a.calculatedValue.netValue);

    return NextResponse.json({
      success: true,
      data: offersWithValues,
      count: offersWithValues.length,
    });
  } catch (error) {
    console.error('Error fetching offers:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to fetch offers' },
      { status: 500 }
    );
  }
}
