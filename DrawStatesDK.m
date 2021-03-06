function varargout=DrawStatesDK(Mats,nShocks,nStateVar,nObsVar,T,isDrawStates)

% DrawStatesDK
%
% Draws from the Durbin Koopman Disturbance Smoother.
%
% Usage:
%   StateDraw = DrawStatesDK(...
%                 Data,s00,sig00,G1,G2,H,nShocks,nStateVar,nObsVar,T,...
%                 isDrawStates)
%   [StateDraw,ShockDraw] = DrawStatesDK(...)
%   [StateDraw,ShockDraw,StateDraw0] = DrawStatesDK(...)
%
% See also:
% CRDrawStates
% .........................................................................
% 
% Created: November 1, 2012 by Vasco Curdia
% Updated: November 9, 2012 by Vasco Curdia
% Updated: January 16, 2013 by Vasco Curdia
%   - Notation
% Updated: January 23, 2013 by Vasco Curdia
%   - Notation
% Updated: October 28, 2013 by Vasco Curdia
%   - Adapted from CRDrawStatesDK
% 
% Copyright 2012-2013 by Vasco Curdia

%% ------------------------------------------------------------------------

%% Prepare
if ~exist('isDrawStates','var'), isDrawStates=1; end

DataDetrended = Mats.Data.Raw-Mats.Data.Trend;
sig00 = Mats.KF.sig00;
s00 = Mats.KF.s00;
G1 = Mats.REE.G1;
G2 = Mats.REE.G2;
H = Mats.ObsEq.H;
IdxNaN = Mats.Data.IdxNaN;

%% Generate random states
Er = isDrawStates*normrnd(0,1,nShocks,T);
Sr = zeros(nStateVar,T+1);
try 
  Sr(:,1) = s00+isDrawStates*mvnrnd(zeros(1,nStateVar),sig00)';
catch
%   fprintf('Warning: sig00 no semidefinite positive. using only diag elements.\n');
  sig00tmp = diag(sig00);
  sig00tmp(sig00tmp<0)=0;
  sig00 = diag(sig00tmp);
  Sr(:,1) = s00+isDrawStates*mvnrnd(zeros(1,nStateVar),sig00)';
end
for t=1:T
  Sr(:,t+1) = G1*Sr(:,t)+G2*Er(:,t);
end

%% Generate difference between observables and random series
% NOTE: assume that Data is already demeaned
DataDiff = DataDetrended'-H*Sr(:,2:T+1);

%% Run KF on Xs
stt = s00;
sigtt = sig00;
r = zeros(nStateVar,T);
K = cell(T,1);
Om = G2*G2';
for t=1:T
    Ht = H(~IdxNaN(t,:),:);
    sigtt1 = G1*sigtt*G1'+Om;
    Ft = Ht*sigtt1*Ht';
    vt = DataDiff(~IdxNaN(t,:),t)-Ht*G1*stt;
    Kt = sigtt1*Ht'/Ft;
    stt = G1*stt+Kt*vt;
    sigtt = (eye(nStateVar)-Kt*Ht)*sigtt1;
    r(:,t) = Ht'*(Ft\vt);
    K{t} = Kt;
end

%% Run DK
for t=T-1:-1:1
    r(:,t) = r(:,t)+(eye(nStateVar)-...
                     H(~IdxNaN(t,:),:)'*K{t}')*G1'*r(:,t+1);
end
r0 = G1'*r(:,1);

%% Get shocks and states
E = G2'*r;
S = zeros(nStateVar,T+1);
S(:,1) = s00+sig00*r0;
for t=1:T
  S(:,t+1) = G1*S(:,t)+G2*E(:,t);
end
ShockDraw = Er+E;
StateDraw = Sr+S;
StateDraw0 = StateDraw(:,1);
StateDraw = StateDraw(:,2:T+1);

%% prepare output
if nargout==1
    varargout = {StateDraw};
elseif nargout==2
    varargout = {StateDraw,ShockDraw};
else
    varargout = {StateDraw,ShockDraw,StateDraw0};
end

%% ------------------------------------------------------------------------
