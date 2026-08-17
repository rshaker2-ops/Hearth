import { LoginResponseDto, createPartner, updateConfig } from '@immich/sdk';
import { createUserDto } from 'src/fixtures';
import { app, asBearerAuth, utils } from 'src/utils';
import request from 'supertest';
import { beforeAll, describe, expect, it } from 'vitest';

describe('/partners', () => {
  let admin: LoginResponseDto;
  let user1: LoginResponseDto;
  let user2: LoginResponseDto;
  let user3: LoginResponseDto;

  beforeAll(async () => {
    await utils.resetDatabase();

    admin = await utils.adminSetup();

    [user1, user2, user3] = await Promise.all([
      utils.userSetup(admin.accessToken, createUserDto.user1),
      utils.userSetup(admin.accessToken, createUserDto.user2),
      utils.userSetup(admin.accessToken, createUserDto.user3),
    ]);

    await Promise.all([
      createPartner({ partnerCreateDto: { sharedWithId: user2.userId } }, { headers: asBearerAuth(user1.accessToken) }),
      createPartner({ partnerCreateDto: { sharedWithId: user1.userId } }, { headers: asBearerAuth(user2.accessToken) }),
    ]);
  });

  describe('GET /partners', () => {
    it('should get all partners shared by user', async () => {
      const { status, body } = await request(app)
        .get('/partners')
        .set('Authorization', `Bearer ${user1.accessToken}`)
        .query({ direction: 'shared-by' });

      expect(status).toBe(200);
      expect(body).toEqual([expect.objectContaining({ id: user2.userId })]);
    });

    it('should get all partners that share with user', async () => {
      const { status, body } = await request(app)
        .get('/partners')
        .set('Authorization', `Bearer ${user1.accessToken}`)
        .query({ direction: 'shared-with' });

      expect(status).toBe(200);
      expect(body).toEqual([expect.objectContaining({ id: user2.userId })]);
    });
  });

  describe('POST /partners/:id', () => {
    it('should share with new partner', async () => {
      const { status, body } = await request(app)
        .post(`/partners/${user3.userId}`)
        .set('Authorization', `Bearer ${user1.accessToken}`);

      expect(status).toBe(201);
      expect(body).toEqual(expect.objectContaining({ id: user3.userId }));
    });

    it('should not share with new partner if already sharing with this partner', async () => {
      const { status, body } = await request(app)
        .post(`/partners/${user2.userId}`)
        .set('Authorization', `Bearer ${user1.accessToken}`);

      expect(status).toBe(400);
      expect(body).toEqual(expect.objectContaining({ message: 'Partner already exists' }));
    });
  });

  describe('PUT /partners/:id', () => {
    it('should update partner', async () => {
      const { status, body } = await request(app)
        .put(`/partners/${user2.userId}`)
        .set('Authorization', `Bearer ${user1.accessToken}`)
        .send({ inTimeline: false });

      expect(status).toBe(200);
      expect(body).toEqual(expect.objectContaining({ id: user2.userId, inTimeline: false }));
    });

    it('should reject a sharePeople update when the feature is disabled', async () => {
      const { status, body } = await request(app)
        .put(`/partners/${user2.userId}`)
        .set('Authorization', `Bearer ${user1.accessToken}`)
        .send({ sharePeople: true });

      expect(status).toBe(400);
      expect(body).toEqual(
        expect.objectContaining({ message: 'Sharing face recognition data with partners is disabled' }),
      );
    });

    it('should update sharePeople when the feature is enabled', async () => {
      const config = await utils.getSystemConfig(admin.accessToken);
      await updateConfig(
        { systemConfigDto: { ...config, partnerSharing: { sharePeople: true } } },
        { headers: asBearerAuth(admin.accessToken) },
      );

      try {
        const { status, body } = await request(app)
          .put(`/partners/${user2.userId}`)
          .set('Authorization', `Bearer ${user1.accessToken}`)
          .send({ sharePeople: true });

        expect(status).toBe(200);
        expect(body).toEqual(expect.objectContaining({ id: user2.userId, sharePeople: true }));
      } finally {
        await updateConfig(
          { systemConfigDto: { ...config, partnerSharing: { sharePeople: false } } },
          { headers: asBearerAuth(admin.accessToken) },
        );
      }
    });

    it('should reject an update of both inTimeline and sharePeople', async () => {
      const { status, body } = await request(app)
        .put(`/partners/${user2.userId}`)
        .set('Authorization', `Bearer ${user1.accessToken}`)
        .send({ inTimeline: true, sharePeople: false });

      expect(status).toBe(400);
      expect(body).toEqual(
        expect.objectContaining({ message: 'inTimeline and sharePeople cannot be updated in the same request' }),
      );
    });

    it('should reject an empty update', async () => {
      const { status } = await request(app)
        .put(`/partners/${user2.userId}`)
        .set('Authorization', `Bearer ${user1.accessToken}`)
        .send({});

      expect(status).toBe(400);
    });
  });

  describe('DELETE /partners/:id', () => {
    it('should delete partner', async () => {
      const { status } = await request(app)
        .delete(`/partners/${user3.userId}`)
        .set('Authorization', `Bearer ${user1.accessToken}`);

      expect(status).toBe(204);
    });

    it('should throw a bad request if partner not found', async () => {
      const { status, body } = await request(app)
        .delete(`/partners/${user3.userId}`)
        .set('Authorization', `Bearer ${user1.accessToken}`);

      expect(status).toBe(400);
      expect(body).toEqual(expect.objectContaining({ message: 'Partner not found' }));
    });
  });
});
