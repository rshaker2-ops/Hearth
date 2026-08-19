<script lang="ts">
  import UserPageLayout from '$lib/components/layouts/UserPageLayout.svelte';
  import GalleryViewer from '$lib/components/shared-components/gallery-viewer/GalleryViewer.svelte';
  import { assetMultiSelectManager } from '$lib/managers/asset-multi-select-manager.svelte';
  import type { Viewport } from '$lib/managers/timeline-manager/types';
  import { searchRandom, type AssetResponseDto } from '@immich/sdk';
  import { IconButton } from '@immich/ui';
  import { mdiDiceMultipleOutline } from '@mdi/js';
  import { t } from 'svelte-i18n';
  import type { PageData } from './$types';

  interface Props {
    data: PageData;
  }

  let { data }: Props = $props();

  let assets: AssetResponseDto[] = $state(data.assets);
  let reshuffling = $state(false);

  const viewport: Viewport = $state({ width: 0, height: 0 });

  const handleReshuffle = async () => {
    reshuffling = true;
    try {
      assets = await searchRandom({ randomSearchDto: { size: 100 } });
    } finally {
      reshuffling = false;
    }
  };
</script>

<UserPageLayout hideNavbar={assetMultiSelectManager.selectionActive} title={data.meta.title} scrollbar={true}>
  {#snippet buttons()}
    <IconButton
      shape="round"
      color="secondary"
      variant="ghost"
      icon={mdiDiceMultipleOutline}
      aria-label={$t('reshuffle')}
      title={$t('reshuffle')}
      disabled={reshuffling}
      onclick={handleReshuffle}
    />
  {/snippet}

  <div bind:clientHeight={viewport.height} bind:clientWidth={viewport.width} class="mt-2">
    <GalleryViewer bind:assets assetInteraction={assetMultiSelectManager} {viewport} pageHeaderOffset={54} />
  </div>
</UserPageLayout>
