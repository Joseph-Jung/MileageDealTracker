import { prisma } from '../client';
import type { Prisma } from '@prisma/client';

export class SubscriberRepository {
  async create(data: Prisma.SubscriberCreateInput) {
    return prisma.subscriber.create({ data });
  }

  async findByEmail(email: string) {
    return prisma.subscriber.findUnique({
      where: { email },
      include: {
        preferences: true,
      },
    });
  }

  async findByVerificationToken(token: string) {
    return prisma.subscriber.findUnique({
      where: { verificationToken: token },
    });
  }

  async findByUnsubscribeToken(token: string) {
    return prisma.subscriber.findUnique({
      where: { unsubscribeToken: token },
    });
  }

  async verifyEmail(id: string) {
    return prisma.subscriber.update({
      where: { id },
      data: {
        emailVerified: true,
        verificationToken: null,
      },
    });
  }

  async unsubscribe(id: string) {
    return prisma.subscriber.update({
      where: { id },
      data: {
        unsubscribedAt: new Date(),
      },
    });
  }

  async getVerifiedSubscribers() {
    return prisma.subscriber.findMany({
      where: {
        emailVerified: true,
        unsubscribedAt: null,
      },
      include: {
        preferences: true,
      },
    });
  }

  async updatePreferences(subscriberId: string, preferences: Prisma.SubscriberPreferenceCreateManyInput[]) {
    // Delete existing preferences
    await prisma.subscriberPreference.deleteMany({
      where: { subscriberId },
    });

    // Create new preferences
    return prisma.subscriberPreference.createMany({
      data: preferences.map(pref => ({
        ...pref,
        subscriberId,
      })),
    });
  }
}
