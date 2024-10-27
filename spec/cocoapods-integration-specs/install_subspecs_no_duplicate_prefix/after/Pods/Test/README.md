NOTE: This has been superceded by an official Pod. This is only currently used for integration testing with CocoaPods since it is very simple.

AFRaptureXMLRequestOperation
============================

AFRaptureXMLRequestOperation is an extension for [AFNetworking](http://github.com/AFNetworking/AFNetworking/) that provides an 
interface to parse XML using [RaptureXML](https://github.com/ZaBlanc/RaptureXML). This uses ARC.

## Example Usage
    AFRaptureXMLRequestOperation *operation = [AFRaptureXMLRequestOperation XMLParserRequestOperationWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://legalindexes.indoff.com/sitemap.xml"]] success:^(NSURLRequest *request, NSHTTPURLResponse *response, RXMLElement *XMLElement) {
       // Do something with XMLElement 
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, RXMLElement *XMLElement) {
        // Handle Error
    }];

    [operation start];
