import { prisma } from '../client';
import type { Prisma } from '@prisma/client';

export class OfferSnapshotRepository {
  async create(data: Prisma.OfferSnapshotCreateInput) {
    return prisma.offerSnapshot.create({ data });
  }

  async findByOfferId(offerId: string, limit = 52) {
    return prisma.offerSnapshot.findMany({
      where: { offerId },
      orderBy: {
        capturedAt: 'desc',
      },
      take: limit,
    });
  }

  async getLatest(offerId: string) {
    return prisma.offerSnapshot.findFirst({
      where: { offerId },
      orderBy: {
        capturedAt: 'desc',
      },
    });
  }

  async getWeeklyChanges(daysBack = 7) {
    const since = new Date();
    since.setDate(since.getDate() - daysBack);

    return prisma.offerSnapshot.findMany({
      where: {
        capturedAt: {
          gte: since,
        },
        diffSummary: {
          not: null,
        },
      },
      include: {
        offer: {
          include: {
            product: {
              include: {
                issuer: true,
              },
            },
          },
        },
      },
      orderBy: {
        capturedAt: 'desc',
      },
    });
  }
}
