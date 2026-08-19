import { searchRandom } from '@immich/sdk';
import { authenticate } from '$lib/utils/auth';
import { getFormatter } from '$lib/utils/i18n';
import type { PageLoad } from './$types';

export const load = (async ({ url }) => {
  await authenticate(url);
  const $t = await getFormatter();
  const assets = await searchRandom({ randomSearchDto: { size: 100 } });

  return {
    assets,
    meta: {
      title: $t('shuffle'),
    },
  };
}) satisfies PageLoad;
