% All functions, that are used in this code, are described on the "MATLAb Functions" document.
 % you can see more detail in the functions codes. 
 
 % Author  : Jamal Beiranvand (Jamalbeiranvand@gmail.com)
 % google scholar: https://scholar.google.com/citations?user=S6LywwsAAAAJ&hl=en
 % Date : 14/05/2020
%%
clear;
clc
warning off
%% User pannel Parameters (you may have to change some values in the "Plot" section)
addpath(('F:\Ph.D\Matlab\Functions') )% Add path of the "Functions" folder.
K=3;                           % number of users
b =2;                    % Values of Bits, it can be a vector, you can use 'inf' for infinity resolution
NT=3:8;
Rxz = 1;                       % Number of the receiver antennas on z axis
Rxy = 1;                       % Number of the receiver antennas on y axis
% % Ns  = 1;                       % Number of data streams
Nrf = K;                     % Number of RF chains at BS
Ncl =5;                       % Number of Channel clusters(Scatters)
% Nray= 1;                       % Number of rays in each cluster
SNR_dB =10;             % Signal to noise ratio in dB
TxSector=[120 120];
RxSector=[90 90];
realization = 50;              % Iteration of simulation
%% Initialize Parameters
SNR = 10.^(SNR_dB./10)*K;        
% %% Allocate memory space for matrices
% R_ZF=zeros(length(SNR_dB),realization);
% R_MMSE=zeros(length(SNR_dB),realization);
% R_MRC=zeros(K,1);
for Sn=1:length(NT)
    Txz = NT(Sn);                       % Number of the transmitter antennas on z axis
    Txy =NT(Sn);                      % Number of the transmitter antennas on y axis
    Tx  = [Txz,Txy];               % Srtucture of the transmit antanna array
    Rx  = [Rxz,Rxy];               % Srtucture of the receiver antanna array 
    Nt  = Txz*Txy;                 % Number of the transmit antennas
    Nr  = Rxz*Rxy;                 % Number of the receive antennas

    for it=1:realization
            Phs=1/(sqrt(Nt))*exp(1j*(0:2^b-1)*2*pi/(2^b));
             [H,At,Ar,~]=MU_Channel(Tx,K,Ncl,'TxSector',TxSector,'RxSector',RxSector);
%              [H,~,~,~]=MU_Channel(Tx,K,Ncl); 
             H=H.';
             %% Initialize FRF, FBB.
             q=ones(K,1)/SNR;
             [~,index]=max(abs(H).'); 
             FRF=zeros(Nt,Nrf);
             for i=1:Nt
             FRF(i,index(i))=1/(sqrt(Nt));
             end
             FBB=sqrt(SNR)*(randn(Nrf,K)+1j*randn(Nrf,K));

             for TConv=1:20
                 %% Analog beamformer design:
                 SNRMatrix=H'*FRF*FBB;
                 SNRvec=abs(diag(SNRMatrix)).^2;
                 I=sum(abs(SNRMatrix).^2,2)-SNRvec;
                 SINRk=SNRvec./(I+1);
                  R=sum(log2(1+SINRk));
                 for i=1:Nt  
                     R=0;
                     for nrf=1:Nrf
                         for ps=1:length(Phs)
                             FRF(i,:)=0;
                             FRF(i,nrf)=Phs(ps);
                             SNRMatrix=H'*FRF*FBB;
                             SNRvec=abs(diag(SNRMatrix)).^2;
                             I=sum(abs(SNRMatrix).^2,2)-SNRvec;
                             SINRk=SNRvec./(I+1);
                             if sum(log2(1+SINRk))>R
                                R=sum(log2(1+SINRk));
                                nrfs=nrf;
                                Phas=Phs(ps);
                             end             
                         end                        
                     end         
                     FRF(i,:)=0;
                     FRF(i,nrfs)=Phas;                     
                 end
%                  R
                %  sum(FRF~=0,2)

                 %% Digital beamformer design:

                 for k=1:K
                     h_hat(k,:)=H(:,k)'*(FRF);
                 end
                 %% Update uplink beamformer fk as (46) and (47).
                 for Covr=1:30
                     for k=1:K
                         Sig=zeros(K,K);
                         for j=1:K
                             if j~=k
                                 Sig=Sig+q(j)*h_hat(j,:)'*h_hat(j,:);
                             end
                         end
                         fk(:,k)= inv(Sig+eye(K,K))*h_hat(k,:)';
                         fk(:,k)=fk(:,k)/norm(fk(:,k));
                         Eps(k)=h_hat(k,:)*inv(Sig+eye(K,K))*h_hat(k,:)';
%                           Eps(k)=h_hat(k,:)*fk(:,k);
                     end

                     % Update uplink power qk as (48).
                     q=WaterFilling(Eps,SNR);
                %      sum(q)
                 end
                 %% SINRkUp
                 for k=1:K
                     num=q(k)*fk(:,k)'*h_hat(k,:)'*h_hat(k,:)*fk(:,k);
                     d=zeros(size(h_hat(k,:)'*h_hat(k,:)));
                     for j=1:K
                         if j~=k
                             d=d+q(j)*h_hat(j,:)'*h_hat(j,:);
                         end
                     end
                     dem=fk(:,k)'*d*fk(:,k)+1;
                     SINRkUp(k)=num/dem;
                 end
                 SINRkUp(SINRkUp==0)=1;
                %% Compute downlink beamformer FBB by (49)-(51).
                Bmatix=zeros(K,K);
                for i=1:K
                    for j=1:K
                        if i==j
                            if SINRkUp(i)==0
%                                 x=1
                                B(i,j)=0;
                            else
                                B(i,j)=abs(h_hat(i,:)*fk(:,j))/SINRkUp(i);
                            end
                        else
                                B(i,j)=-abs(h_hat(i,:)*fk(:,j))^2;
                        end
                    end
                end
                Binv=inv(B.');
                for k=1:K
                    pk(k)=sum(Binv(k,:));
                end
                for k=1:K
                    FBBhat(:,k)=sqrt(pk(k))*fk(:,k);
                end
                %% Normalize FBB as (52).
%                 FBB=sqrt(SNR(Sn)*K)*FBBhat/norm(FRF*FBBhat,'fro');
                  FBB=sqrt(SNR)*FBBhat/norm(FRF*FBBhat,'fro');
             end
%     SNR(Sn)        
%     sum(sum(abs(FRF*FBB).^2))
    SNRMatrix=H'*FRF*FBB;
    SNRvec=abs(diag(SNRMatrix)).^2;
    I=sum(abs(SNRMatrix).^2,2)-SNRvec;
    SINRk=SNRvec./(I+1);
    RR(it)=sum(log2(1+SINRk));
     end
     Rsum(Sn)=mean(RR)
end
plot(NT.^2,Rsum)
axis([min(NT.^2) max(NT.^2) 4 24])