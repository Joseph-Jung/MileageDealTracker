import { prisma } from '../client';
import type { Prisma } from '@prisma/client';

export class CardProductRepository {
  async findAll() {
    return prisma.cardProduct.findMany({
      include: {
        issuer: true,
        _count: {
          select: { offers: true },
        },
      },
      orderBy: {
        name: 'asc',
      },
    });
  }

  async findBySlug(slug: string) {
    return prisma.cardProduct.findUnique({
      where: { slug },
      include: {
        issuer: true,
        offers: {
          where: {
            status: 'ACTIVE',
          },
        },
      },
    });
  }

  async create(data: Prisma.CardProductCreateInput) {
    return prisma.cardProduct.create({ data });
  }

  async update(id: string, data: Prisma.CardProductUpdateInput) {
    return prisma.cardProduct.update({
      where: { id },
      data,
    });
  }

  async delete(id: string) {
    return prisma.cardProduct.delete({
      where: { id },
    });
  }
}
