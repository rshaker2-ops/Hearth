<script lang="ts">
  import ButtonContextMenu from '$lib/components/shared-components/context-menu/ButtonContextMenu.svelte';
  import MenuOption from '$lib/components/shared-components/context-menu/MenuOption.svelte';
  import { timelineSort, type TimelineSortSettings } from '$lib/stores/preferences.store';
  import { AssetOrder, AssetOrderBy } from '@immich/sdk';
  import { mdiCheck, mdiSortCalendarDescending } from '@mdi/js';
  import { t, type Translations } from 'svelte-i18n';

  type SortChoice = TimelineSortSettings & { label: Translations };

  const choices: SortChoice[] = [
    { order: AssetOrder.Desc, orderBy: AssetOrderBy.TakenAt, label: 'sort_taken_newest_first' },
    { order: AssetOrder.Asc, orderBy: AssetOrderBy.TakenAt, label: 'sort_taken_oldest_first' },
    { order: AssetOrder.Desc, orderBy: AssetOrderBy.CreatedAt, label: 'sort_added_newest_first' },
    { order: AssetOrder.Asc, orderBy: AssetOrderBy.CreatedAt, label: 'sort_added_oldest_first' },
  ];

  const isActive = (choice: SortChoice) =>
    $timelineSort.order === choice.order && $timelineSort.orderBy === choice.orderBy;
</script>

<ButtonContextMenu icon={mdiSortCalendarDescending} title={$t('sort_photos')} direction="left">
  {#each choices as choice (choice.label)}
    <MenuOption
      text={$t(choice.label)}
      icon={isActive(choice) ? mdiCheck : undefined}
      onClick={() => ($timelineSort = { order: choice.order, orderBy: choice.orderBy })}
    />
  {/each}
</ButtonContextMenu>
