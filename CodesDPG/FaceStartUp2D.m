% N = 5; Nf = 5;  % when N = even, Nf = N-1, fails?
% % [Nv, VX, VY, K, EToV] = MeshReaderGambit2D('squarereg.neu');
% %     Nv = 3;  VX = VX(EToV(1,:)); VY = VY(EToV(1,:));
% %     EToV = [3 1 2];  K = 1;
% [Nv, VX, VY, K, EToV] = MeshReaderGambit2D('Maxwell1.neu');
% StartUp2D;

if (Nf>N) 
    warning('Nf > N.')
end

[fM fP fpairs] = getFaceInfo();
NfacesU = size(fpairs,2);
bfaces = any(fM==fP); 

%% set up flux data
Nfrp = Nf+1;

% get flux ids on boundaries
[rfr xf yf nxf nyf] = getFaceNodes(Nf,fM,fpairs);

% fmap = Nfaces*Nfrp x K array of face node dofs
sharedFaces = ~ismember(fpairs(2,:),fpairs(1,:));
fmap = zeros(Nfrp,Nfaces*K);
fmap(:,fpairs(1,:)) = reshape(1:Nfrp*NfacesU,Nfrp,NfacesU);
fmap(:,fpairs(2,sharedFaces)) = fmap(:,fpairs(1,sharedFaces));
fmap = reshape(fmap,Nfrp*Nfaces,K);

fmapB = reshape(1:Nfrp*NfacesU,Nfrp,NfacesU); 
fmapB = fmapB(:,bfaces); 
fmapB = fmapB(:); 

%% set up trace data - discontinuous for now
if ~exist('Nt')
    Nt = [];
end
if ~isempty(Nt)   
   Ntrp = Nt+1;
   
   % get flux ids on boundaries
   [rtr xt yt nxt nyt] = getFaceNodes(Nt,fM,fpairs);
   
   % fmap = Nfaces*Nfrp x K array of face node dofs
   sharedFaces = ~ismember(fpairs(2,:),fpairs(1,:));
   tmap = zeros(Ntrp,Nfaces*K);
   tmap(:,fpairs(1,:)) = reshape(1:Ntrp*NfacesU,Ntrp,NfacesU);
   tmap(:,fpairs(2,sharedFaces)) = tmap(:,fpairs(1,sharedFaces));
   tmap = reshape(tmap,Ntrp*Nfaces,K);
   
   tmapB = reshape(1:Ntrp*NfacesU,Ntrp,NfacesU);   
   tmapB = tmapB(:,bfaces);
   tmapB = tmapB(:);
end

% plotVerts
% % plot(x,y,'rs')
% % plot(x(vmapB),y(vmapB),'k*','markersize',12)
% plot(xf,yf,'g^')
% plot(xf(fmapB),yf(fmapB),'mo','markersize',12)