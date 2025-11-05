import { prisma } from '../client';
import type { Offer, OfferStatus, Prisma } from '@prisma/client';

export interface OfferFilters {
  issuerSlug?: string;
  currencyCode?: string;
  minBonus?: number;
  maxSpend?: number;
  status?: OfferStatus;
  firstYearWaived?: boolean;
}

export class OfferRepository {
  async findActive(filters?: OfferFilters) {
    const where: Prisma.OfferWhereInput = {
      status: filters?.status || 'ACTIVE',
      ...(filters?.minBonus && { bonusPoints: { gte: filters.minBonus } }),
      ...(filters?.maxSpend && { minSpendAmount: { lte: filters.maxSpend } }),
      ...(filters?.firstYearWaived !== undefined && { firstYearWaived: filters.firstYearWaived }),
      ...(filters?.issuerSlug && {
        product: {
          issuer: {
            slug: filters.issuerSlug,
          },
        },
      }),
      ...(filters?.currencyCode && {
        product: {
          currencyCode: filters.currencyCode,
        },
      }),
    };

    return prisma.offer.findMany({
      where,
      include: {
        product: {
          include: {
            issuer: true,
          },
        },
      },
      orderBy: {
        lastVerifiedAt: 'desc',
      },
    });
  }

  async findById(id: string) {
    return prisma.offer.findUnique({
      where: { id },
      include: {
        product: {
          include: {
            issuer: true,
          },
        },
        snapshots: {
          orderBy: {
            capturedAt: 'desc',
          },
          take: 1,
        },
      },
    });
  }

  async findByProductId(productId: string) {
    return prisma.offer.findMany({
      where: { productId },
      include: {
        product: {
          include: {
            issuer: true,
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
    });
  }

  async create(data: Prisma.OfferCreateInput) {
    return prisma.offer.create({
      data,
      include: {
        product: {
          include: {
            issuer: true,
          },
        },
      },
    });
  }

  async update(id: string, data: Prisma.OfferUpdateInput) {
    return prisma.offer.update({
      where: { id },
      data,
      include: {
        product: {
          include: {
            issuer: true,
          },
        },
      },
    });
  }

  async delete(id: string) {
    return prisma.offer.delete({
      where: { id },
    });
  }

  async updateStatus(id: string, status: OfferStatus) {
    return prisma.offer.update({
      where: { id },
      data: { status },
    });
  }
}
