function primalDPG_poisson

Globals2D

% Polynomial order used for approximation
Ntrial = 4;
Ntest = Ntrial+2;
Nflux = Ntrial;

N = Ntest;

% Read in Mesh
[Nv, VX, VY, K, EToV] = MeshReaderGambit2D('squarereg.neu');
% [Nv, VX, VY, K, EToV] = MeshReaderGambit2D('squareireg.neu');
% [Nv, VX, VY, K, EToV] = MeshReaderGambit2D('block2.neu');
[Nv, VX, VY, K, EToV] = MeshReaderGambit2D('Maxwell1.neu');
% [Nv, VX, VY, K, EToV] = MeshReaderGambit2D('Maxwell05.neu');
% [Nv, VX, VY, K, EToV] = MeshReaderGambit2D('Maxwell025.neu');
% [Nv, VX, VY, K, EToV] = MeshReaderGambit2D('Maxwell0125.neu');

% Initialize solver and construct grid and metric
StartUp2D;

% get block operators
[M, Dx, Dy] = getBlockOps();
[AK, BK] = getVolOp(M,Dx,Dy);
f = ones(Np*K,1);
b = M*f;

[R vmapBT] = getCGRestriction();
[Rr vmapBTr xr yr] = pRestrictCG(Ntrial); % restrict test to trial space
[Bhat vmapBF xf yf nxf nyf] = getMortarConstraint(Nflux);

B = BK*Rr';   % form rectangular bilinear form matrix

[nV nU] = size(B); % num test nodes, num trial nodes
nM = size(Bhat,1); % num mortar nodes
nTrial = nU + nM;

% penalty/robin BCs 
bmask = abs(y(vmapB)) > 1 - NODETOL; % top/bottom boundaries
[Mb Eb] = getBoundaryMatrix(bmask(:));
u0tb = 1+x(vmapB);
% B = B + 1e6*Eb'*Mb*Eb*Rr'; % this adds a penalty term on u 
% b = b + 1e6*Eb'*Mb*u0tb;

Bh = [B Bhat'];
Tblk = cell(K,1);
if 1
    tic
    for i = 1:K % independently invert
        inds = (i-1)*Np + (1:Np);
        Tblk{i} = AK(inds,inds)\Bh(inds,:);
        disp(['on element ' num2str(i)])
        %             Tblk{i} = Bh(inds,:);
    end
    disp(['time for test function computation = ', num2str(toc)])
else
    disp('parfor implementation...')
    t = 0;
    tic
    AKi = cell(K,1); Bi = cell(K,1);
    for i = 1:K
        inds = (i-1)*Np + (1:Np);
        AKi{i} = AK(inds,inds);
        Bi{i} = Bh(inds,:);
    end
    t=t+toc
    tic
    parfor i = 1:K
        Tblk{i} = AKi{i}\Bi{i};
    end
    t = t+toc
end
T = cell2mat(Tblk);
A = T'*Bh;

% forcing
b = T'*b;

% BCs on u
u0 = zeros(size(B,2),1);
left = xr < -1+NODETOL;
u0(vmapBTr) = left.*sqrt(1-yr.^2); 
right = xr > 1-NODETOL;

% BCs on flux
uh0 = zeros(nM,1); 
leftf = xf < -1+NODETOL; % right boundary
rightf = xf > 1-NODETOL; % right boundary
uh0(vmapBF) = -rightf.*nxf.*((yf<=0) - (yf>0)).^0;  % BC data on -du/dn

U0 = [u0;uh0];

b = b - A*U0; % get lift

% BCs on U: ordered first
left = xr < -1+NODETOL;
% vmapBTr(~left) = []; % remove strong BCs on u except for left
vmapBTr(right) = []; % remove strong BCs on right
b(vmapBTr) = U0(vmapBTr);
A(vmapBTr,:) = 0; A(:,vmapBTr) = 0;
A(vmapBTr,vmapBTr) = speye(length(vmapBTr));

% homogeneous BCs on V are implied by mortars.
% BCs on mortars removes BCs on test functions.
% vmapBF(~leftf) = []; % impose BCs on right outflow
vmapBF(~rightf) = []; % impose BCs on right outflow
bci = nU + vmapBF; % skip over u dofs
b(bci) = uh0(vmapBF);
A(bci,:) = 0; A(:,bci)=0;
A(bci,bci) = speye(length(bci));

U = A\b;
u = Rr'*U(1:nU);

% Nplot = 25;
Nplot = Ntrial;
% [xu,yu] = EquiNodes2D(Nplot); 
[xu,yu] = Nodes2D(Nplot); 
[ru, su] = xytors(xu,yu);
Vu = Vandermonde2D(N,ru,su); Iu = Vu*invV;
xu = 0.5*(-(ru+su)*VX(va)+(1+ru)*VX(vb)+(1+su)*VX(vc));
yu = 0.5*(-(ru+su)*VY(va)+(1+ru)*VY(vb)+(1+su)*VY(vc));
figure
color_line3(xu,yu,Iu*reshape(u,Np,K),Iu*reshape(u,Np,K),'.');

title('DPG with fluxes and traces')

% keyboard

function [Test, Trial] = getVolOp(M,Dx,Dy)

Globals2D
Ks = Dx'*M*Dx + Dy'*M*Dy;

% Poisson
Test = M + Ks;
Trial = Ks;


function [M, Dx, Dy] = getBlockOps()

Globals2D

blkDr = kron(speye(K),Dr);
blkDs = kron(speye(K),Ds);
blkM = kron(speye(K),MassMatrix);

M = spdiag(J(:))*blkM; % J = h^2
Dx = spdiag(rx(:))*blkDr + spdiag(sx(:))*blkDs;
Dy = spdiag(ry(:))*blkDr + spdiag(sy(:))*blkDs;

