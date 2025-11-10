import { prisma } from '../client';
import type { Prisma } from '@prisma/client';

export class IssuerRepository {
  async findAll() {
    return prisma.issuer.findMany({
      include: {
        _count: {
          select: { products: true },
        },
      },
      orderBy: {
        name: 'asc',
      },
    });
  }

  async findBySlug(slug: string) {
    return prisma.issuer.findUnique({
      where: { slug },
      include: {
        products: {
          include: {
            offers: {
              where: {
                status: 'ACTIVE',
              },
            },
          },
        },
      },
    });
  }

  async create(data: Prisma.IssuerCreateInput) {
    return prisma.issuer.create({ data });
  }

  async update(id: string, data: Prisma.IssuerUpdateInput) {
    return prisma.issuer.update({
      where: { id },
      data,
    });
  }

  async delete(id: string) {
    return prisma.issuer.delete({
      where: { id },
    });
  }
}
