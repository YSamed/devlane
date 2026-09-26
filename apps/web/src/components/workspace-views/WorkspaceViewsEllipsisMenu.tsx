import { useTranslation } from 'react-i18next';
import { useLocation } from 'react-router-dom';
import { ExternalLink, Link2, MoreVertical } from 'lucide-react';

import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/shadcn/ui/dropdown-menu';

export function WorkspaceViewsEllipsisMenu() {
  const { t } = useTranslation();
  const location = useLocation();

  const fullUrl =
    typeof window !== 'undefined' ? window.location.href : `${location.pathname}${location.search}`;

  const handleOpenInNewTab = () => {
    window.open(fullUrl, '_blank', 'noopener,noreferrer');
  };

  const handleCopyLink = async () => {
    try {
      await navigator.clipboard.writeText(fullUrl);
    } catch {
      // ignore
    }
  };

  return (
    <DropdownMenu>
      <DropdownMenuTrigger
        className="flex size-8 shrink-0 items-center justify-center rounded-md border border-transparent text-(--txt-icon-tertiary) hover:bg-(--bg-layer-2) hover:text-(--txt-icon-secondary)"
        aria-label={t('common.moreOptions', 'More options')}
      >
        <MoreVertical size={16} />
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="min-w-[180px]">
        <DropdownMenuItem onSelect={handleOpenInNewTab}>
          <ExternalLink size={14} />
          {t('common.openInNewTab', 'Open in new tab')}
        </DropdownMenuItem>
        <DropdownMenuItem onSelect={handleCopyLink}>
          <Link2 size={14} />
          {t('common.copyLink', 'Copy link')}
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
