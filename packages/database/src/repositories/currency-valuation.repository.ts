import { prisma } from '../client';
import type { Prisma } from '@prisma/client';

export class CurrencyValuationRepository {
  async findAll() {
    return prisma.currencyValuation.findMany({
      orderBy: {
        currencyCode: 'asc',
      },
    });
  }

  async findByCurrencyCode(currencyCode: string) {
    return prisma.currencyValuation.findUnique({
      where: { currencyCode },
    });
  }

  async create(data: Prisma.CurrencyValuationCreateInput) {
    return prisma.currencyValuation.create({ data });
  }

  async update(id: string, data: Prisma.CurrencyValuationUpdateInput) {
    return prisma.currencyValuation.update({
      where: { id },
      data,
    });
  }

  async getBulkValuations() {
    const valuations = await this.findAll();
    return valuations.reduce((acc, val) => {
      acc[val.currencyCode] = Number(val.centsPerPoint);
      return acc;
    }, {} as Record<string, number>);
  }
}
