/**
 * Response for POST /calls/offer (create).
 */
export class CreateOfferResponseDto {
  callId: string;
  channelName: string;
  status: 'ringing';
}

/**
 * Response for POST /calls/offer/:callId/accept.
 */
export class AcceptOfferResponseDto {
  token: string;
  channelName: string;
  appId: string;
  uid: number;
  expiresIn: number;
}
