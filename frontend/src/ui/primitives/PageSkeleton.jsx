import { Skeleton } from './Skeleton.jsx';

export function PageSkeleton() {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px', padding: '24px' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <Skeleton width="200px" height="32px" />
        <Skeleton width="120px" height="40px" borderRadius="100px" />
      </div>
      
      <div style={{ display: 'flex', gap: '16px' }}>
        <Skeleton width="150px" height="24px" />
        <Skeleton width="150px" height="24px" />
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginTop: '16px' }}>
        <Skeleton width="100%" height="60px" />
        <Skeleton width="100%" height="60px" />
        <Skeleton width="100%" height="60px" />
        <Skeleton width="100%" height="60px" />
      </div>
    </div>
  );
}
