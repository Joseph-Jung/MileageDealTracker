import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('Starting seed...');

  // 1. Seed Currency Valuations
  console.log('Seeding currency valuations...');
  await prisma.currencyValuation.createMany({
    data: [
      {
        currencyCode: 'AA',
        centsPerPoint: 1.4,
        notes: 'American Airlines AAdvantage miles',
      },
      {
        currencyCode: 'UA',
        centsPerPoint: 1.2,
        notes: 'United MileagePlus miles',
      },
      {
        currencyCode: 'DL',
        centsPerPoint: 1.1,
        notes: 'Delta SkyMiles',
      },
      {
        currencyCode: 'MR',
        centsPerPoint: 1.7,
        notes: 'American Express Membership Rewards',
      },
      {
        currencyCode: 'UR',
        centsPerPoint: 1.6,
        notes: 'Chase Ultimate Rewards',
      },
      {
        currencyCode: 'TYP',
        centsPerPoint: 1.5,
        notes: 'Citi ThankYou Points',
      },
    ],
    skipDuplicates: true,
  });

  // 2. Seed Issuers
  console.log('Seeding issuers...');
  const citi = await prisma.issuer.upsert({
    where: { slug: 'citi' },
    update: {},
    create: {
      name: 'Citi',
      slug: 'citi',
      website: 'https://www.citi.com/credit-cards',
    },
  });

  const amex = await prisma.issuer.upsert({
    where: { slug: 'american-express' },
    update: {},
    create: {
      name: 'American Express',
      slug: 'american-express',
      website: 'https://www.americanexpress.com',
    },
  });

  const chase = await prisma.issuer.upsert({
    where: { slug: 'chase' },
    update: {},
    create: {
      name: 'Chase',
      slug: 'chase',
      website: 'https://www.chase.com/personal/credit-cards',
    },
  });

  const bankOfAmerica = await prisma.issuer.upsert({
    where: { slug: 'bank-of-america' },
    update: {},
    create: {
      name: 'Bank of America',
      slug: 'bank-of-america',
      website: 'https://www.bankofamerica.com/credit-cards',
    },
  });

  const capitalOne = await prisma.issuer.upsert({
    where: { slug: 'capital-one' },
    update: {},
    create: {
      name: 'Capital One',
      slug: 'capital-one',
      website: 'https://www.capitalone.com/credit-cards',
    },
  });

  const usBank = await prisma.issuer.upsert({
    where: { slug: 'us-bank' },
    update: {},
    create: {
      name: 'U.S. Bank',
      slug: 'us-bank',
      website: 'https://www.usbank.com/credit-cards.html',
    },
  });

  // 3. Seed Card Products
  console.log('Seeding card products...');
  const citiAA = await prisma.cardProduct.upsert({
    where: { slug: 'citi-aadvantage-platinum-select' },
    update: {},
    create: {
      issuerId: citi.id,
      name: 'Citi® / AAdvantage® Platinum Select®',
      slug: 'citi-aadvantage-platinum-select',
      network: 'MASTERCARD',
      type: 'PERSONAL',
      currency: 'AA miles',
      currencyCode: 'AA',
      description: 'Earn American Airlines AAdvantage miles with this travel-focused card',
    },
  });

  const amexGold = await prisma.cardProduct.upsert({
    where: { slug: 'amex-gold-card' },
    update: {},
    create: {
      issuerId: amex.id,
      name: 'American Express® Gold Card',
      slug: 'amex-gold-card',
      network: 'AMEX',
      type: 'PERSONAL',
      currency: 'Membership Rewards',
      currencyCode: 'MR',
      description: 'Earn Membership Rewards points on dining and groceries',
    },
  });

  const chaseSapphirePreferred = await prisma.cardProduct.upsert({
    where: { slug: 'chase-sapphire-preferred' },
    update: {},
    create: {
      issuerId: chase.id,
      name: 'Chase Sapphire Preferred®',
      slug: 'chase-sapphire-preferred',
      network: 'VISA',
      type: 'PERSONAL',
      currency: 'Ultimate Rewards',
      currencyCode: 'UR',
      description: 'Popular travel rewards card with transferable points',
    },
  });

  const capOneVenture = await prisma.cardProduct.upsert({
    where: { slug: 'capital-one-venture' },
    update: {},
    create: {
      issuerId: capitalOne.id,
      name: 'Capital One Venture Rewards',
      slug: 'capital-one-venture',
      network: 'VISA',
      type: 'PERSONAL',
      currency: 'Capital One Miles',
      currencyCode: 'UR', // Approximate value similar to UR
      description: 'Earn unlimited 2X miles on every purchase',
    },
  });

  // 4. Seed Sample Offers
  console.log('Seeding offers...');
  const citiAAOffer = await prisma.offer.upsert({
    where: { id: 'seed-citi-aa-1' },
    update: {},
    create: {
      id: 'seed-citi-aa-1',
      productId: citiAA.id,
      headline: 'Earn 80,000 AAdvantage bonus miles',
      bonusPoints: 80000,
      minSpendAmount: 6000,
      minSpendWindowDays: 90,
      annualFee: 99,
      firstYearWaived: true,
      statementCredits: 0,
      landingUrl: 'https://www.citi.com/credit-cards/citi-aadvantage-platinum-select-card',
      sourceType: 'PUBLIC',
      geo: 'US',
      status: 'ACTIVE',
      lastVerifiedAt: new Date(),
      publishedAt: new Date(),
    },
  });

  const amexGoldOffer = await prisma.offer.upsert({
    where: { id: 'seed-amex-gold-1' },
    update: {},
    create: {
      id: 'seed-amex-gold-1',
      productId: amexGold.id,
      headline: 'Earn 90,000 Membership Rewards points',
      bonusPoints: 90000,
      minSpendAmount: 6000,
      minSpendWindowDays: 180,
      annualFee: 325,
      firstYearWaived: false,
      statementCredits: 120, // Monthly dining and Uber credits
      landingUrl: 'https://www.americanexpress.com/us/credit-cards/card/gold-card',
      sourceType: 'PUBLIC',
      geo: 'US',
      status: 'ACTIVE',
      lastVerifiedAt: new Date(),
      publishedAt: new Date(),
    },
  });

  const chaseSapphireOffer = await prisma.offer.upsert({
    where: { id: 'seed-chase-sapphire-1' },
    update: {},
    create: {
      id: 'seed-chase-sapphire-1',
      productId: chaseSapphirePreferred.id,
      headline: 'Earn 75,000 bonus points',
      bonusPoints: 75000,
      minSpendAmount: 4000,
      minSpendWindowDays: 90,
      annualFee: 95,
      firstYearWaived: false,
      statementCredits: 0,
      landingUrl: 'https://www.chase.com/personal/credit-cards/sapphire/preferred',
      sourceType: 'PUBLIC',
      geo: 'US',
      status: 'ACTIVE',
      lastVerifiedAt: new Date(),
      publishedAt: new Date(),
    },
  });

  // 5. Seed Historical Snapshots (to show trend)
  console.log('Seeding offer snapshots...');

  // Historical snapshots for Citi AA (showing bonus increase)
  await prisma.offerSnapshot.createMany({
    data: [
      {
        offerId: citiAAOffer.id,
        capturedAt: new Date('2024-10-01'),
        bonusPoints: 65000,
        minSpendAmount: 4000,
        minSpendWindowDays: 90,
        annualFee: 99,
        statementCredits: 0,
        expiresOn: null,
        landingUrl: 'https://www.citi.com/credit-cards/citi-aadvantage-platinum-select-card',
      },
      {
        offerId: citiAAOffer.id,
        capturedAt: new Date('2024-10-27'),
        bonusPoints: 75000,
        minSpendAmount: 5000,
        minSpendWindowDays: 90,
        annualFee: 99,
        statementCredits: 0,
        expiresOn: null,
        landingUrl: 'https://www.citi.com/credit-cards/citi-aadvantage-platinum-select-card',
        diffSummary: 'Bonus increased 65,000 → 75,000; min spend increased $4,000 → $5,000',
      },
      {
        offerId: citiAAOffer.id,
        capturedAt: new Date('2024-11-03'),
        bonusPoints: 80000,
        minSpendAmount: 6000,
        minSpendWindowDays: 90,
        annualFee: 99,
        statementCredits: 0,
        expiresOn: null,
        landingUrl: 'https://www.citi.com/credit-cards/citi-aadvantage-platinum-select-card',
        diffSummary: 'Bonus increased 75,000 → 80,000; min spend increased $5,000 → $6,000',
      },
    ],
    skipDuplicates: true,
  });

  // Historical snapshots for Amex Gold
  await prisma.offerSnapshot.createMany({
    data: [
      {
        offerId: amexGoldOffer.id,
        capturedAt: new Date('2024-09-15'),
        bonusPoints: 60000,
        minSpendAmount: 6000,
        minSpendWindowDays: 180,
        annualFee: 325,
        statementCredits: 120,
        expiresOn: null,
        landingUrl: 'https://www.americanexpress.com/us/credit-cards/card/gold-card',
      },
      {
        offerId: amexGoldOffer.id,
        capturedAt: new Date('2024-10-15'),
        bonusPoints: 90000,
        minSpendAmount: 6000,
        minSpendWindowDays: 180,
        annualFee: 325,
        statementCredits: 120,
        expiresOn: null,
        landingUrl: 'https://www.americanexpress.com/us/credit-cards/card/gold-card',
        diffSummary: 'Bonus increased 60,000 → 90,000 (50% increase!)',
      },
    ],
    skipDuplicates: true,
  });

  console.log('Seed completed successfully!');
}

main()
  .then(async () => {
    await prisma.$disconnect();
  })
  .catch(async (e) => {
    console.error('Error during seed:', e);
    await prisma.$disconnect();
    process.exit(1);
  });
