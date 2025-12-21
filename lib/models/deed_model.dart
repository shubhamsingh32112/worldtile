/// Deed model with strict typing
/// Represents a digital land ownership deed
class DeedModel {
  final String id;
  final String userId;
  final String propertyId;
  final String landSlotId;
  final String ownerName;
  final String plotId;
  final String city;
  final double latitude;
  final double longitude;
  final DeedNFT nft;
  final DeedPayment payment;
  final DateTime issuedAt;
  final String sealNo;

  DeedModel({
    required this.id,
    required this.userId,
    required this.propertyId,
    required this.landSlotId,
    required this.ownerName,
    required this.plotId,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.nft,
    required this.payment,
    required this.issuedAt,
    required this.sealNo,
  });

  factory DeedModel.fromJson(Map<String, dynamic> json) {
    return DeedModel(
      id: json['_id'] as String,
      userId: json['userId'] as String,
      propertyId: json['propertyId'] as String,
      landSlotId: json['landSlotId'] as String,
      ownerName: json['ownerName'] as String,
      plotId: json['plotId'] as String,
      city: json['city'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      nft: DeedNFT.fromJson(json['nft'] as Map<String, dynamic>),
      payment: DeedPayment.fromJson(json['payment'] as Map<String, dynamic>),
      issuedAt: DateTime.parse(json['issuedAt'] as String),
      sealNo: json['sealNo'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      'propertyId': propertyId,
      'landSlotId': landSlotId,
      'ownerName': ownerName,
      'plotId': plotId,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
      'nft': nft.toJson(),
      'payment': payment.toJson(),
      'issuedAt': issuedAt.toIso8601String(),
      'sealNo': sealNo,
    };
  }
}

/// NFT information for the deed
class DeedNFT {
  final String tokenId;
  final String contractAddress;
  final String blockchain;
  final String standard;

  DeedNFT({
    required this.tokenId,
    required this.contractAddress,
    required this.blockchain,
    required this.standard,
  });

  factory DeedNFT.fromJson(Map<String, dynamic> json) {
    return DeedNFT(
      tokenId: json['tokenId'] as String,
      contractAddress: json['contractAddress'] as String,
      blockchain: json['blockchain'] as String,
      standard: json['standard'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tokenId': tokenId,
      'contractAddress': contractAddress,
      'blockchain': blockchain,
      'standard': standard,
    };
  }
}

/// Payment information for the deed
class DeedPayment {
  final String transactionId;
  final String receiver;

  DeedPayment({
    required this.transactionId,
    required this.receiver,
  });

  factory DeedPayment.fromJson(Map<String, dynamic> json) {
    return DeedPayment(
      transactionId: json['transactionId'] as String,
      receiver: json['receiver'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transactionId': transactionId,
      'receiver': receiver,
    };
  }
}

